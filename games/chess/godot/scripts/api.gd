extends Node
## The server's API (worker/api.ts), the live connection to a game, profile pictures, and the
## page around the game (web/bridge.ts) when running in a browser.
##
## In the browser the game is served by the Worker, so requests go to the same origin and carry
## the session cookie. On the desktop (the editor, or a test run), pass the server and a dev
## account after "--":  godot --path godot -- --server=http://127.0.0.1:8787/retro/chess/ --dev-email=a@b.io

signal me_changed

var base := ""                 ## the game's URL, ending in "/"
var token := ""                ## desktop only: the session token, sent as a Bearer header
var me := {}                   ## the signed-in user, or empty
var loaded := false            ## true once we know whether anyone is signed in
var providers: Array = []
var bridge: JavaScriptObject = null
var _avatars := {}             ## path → Texture2D, or an Array of callbacks while loading
var _engine_cb: JavaScriptObject = null


func _ready() -> void:
	if OS.has_feature("web"):
		bridge = JavaScriptBridge.get_interface("chessBridge")
		base = str(bridge.baseUrl())
	else:
		base = "http://127.0.0.1:8787/retro/chess/"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--server="):
				base = a.trim_prefix("--server=")
				if not base.ends_with("/"):
					base += "/"


func is_web() -> bool:
	return bridge != null


## Loads who is signed in. On the desktop with --dev-email, signs in first.
func load_me() -> void:
	if not is_web():
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--dev-email="):
				var email := a.trim_prefix("--dev-email=")
				var name := email.get_slice("@", 0).capitalize()
				var r := await request("auth/dev?format=token&email=%s&name=%s" % [email.uri_encode(), name.uri_encode()], HTTPClient.METHOD_GET, null, false)
				if r.ok:
					token = r.data.token
	var res := await get_json("api/me")
	if res.ok:
		me = res.data.user if res.data.user != null else {}
		providers = res.data.providers
	loaded = true
	me_changed.emit()


func signed_in() -> bool:
	return not me.is_empty()


# ── HTTP ──

## Sends a request. Returns {ok, status, data, error}.
func request(path: String, method := HTTPClient.METHOD_GET, body: Variant = null, is_api := true) -> Dictionary:
	var http := _http()
	# In the browser, fetch keeps its own time; Godot's timeout counts frames, which stall in a busy or hidden tab.
	http.timeout = 0.0 if is_web() else 20.0
	var headers := PackedStringArray()
	if body != null:
		headers.append("Content-Type: application/json")
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var err := http.request(base + path, headers, method, "" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {ok = false, status = 0, data = {}, error = "Can't reach the server. Are you online?"}
	var r: Array = await http.request_completed
	http.queue_free()
	var status: int = r[1]
	var text := (r[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text != "" else {}
	if data == null:
		data = {}
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		push_warning("Request to %s failed: result %d, status %d" % [path, r[0], status])
		return {ok = false, status = 0, data = {}, error = "Can't reach the server. Are you online?"}
	var ok := status >= 200 and status < 300
	var error := "" if ok else (str(data.get("error")) if data is Dictionary and data.has("error") else "Server error %d" % status)
	return {ok = ok, status = status, data = data, error = error}


## An HTTP request node. In the browser, fetch has already undone any compression, so Godot mustn't try.
func _http() -> HTTPRequest:
	var http := HTTPRequest.new()
	http.accept_gzip = not is_web()
	add_child(http)
	return http


func get_json(path: String) -> Dictionary:
	return await request(path)


func post_json(path: String, body: Variant = {}) -> Dictionary:
	return await request(path, HTTPClient.METHOD_POST, body)


func logout() -> void:
	await request("auth/logout", HTTPClient.METHOD_POST, {}, false)
	token = ""
	me = {}
	me_changed.emit()


## Opens a provider's sign-in page; the browser comes back to the game signed in.
func sign_in(provider: String, email := "") -> void:
	var ret: String = str(bridge.returnPath()) if is_web() else "/retro/chess/"
	if provider == "dev":
		if is_web():
			bridge.navigate(base + "auth/dev?email=%s&return=%s" % [email.uri_encode(), ret.uri_encode()])
		else:
			var r := await request("auth/dev?format=token&email=%s" % email.uri_encode(), HTTPClient.METHOD_GET, null, false)
			if r.ok:
				token = r.data.token
			await load_me()
		return
	var url := base + "auth/login/%s?return=%s" % [provider, ret.uri_encode()]
	if is_web():
		bridge.navigate(url)
	else:
		OS.shell_open(url)


# ── Profile pictures ──

## Calls `done(texture)` with a player's picture (null if they have none or it can't load).
func avatar(path: Variant, done: Callable) -> void:
	if path == null or str(path) == "":
		done.call(null)
		return
	var key := str(path)
	if _avatars.has(key):
		var v: Variant = _avatars[key]
		if v is Array:
			v.append(done)
		else:
			done.call(v)
		return
	_avatars[key] = [done]
	var http := _http()
	var headers := PackedStringArray()
	if token != "":
		headers.append("Authorization: Bearer " + token)
	http.request(base + key, headers)
	var r: Array = await http.request_completed
	http.queue_free()
	var tex: Texture2D = null
	if r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200:
		var bytes: PackedByteArray = r[3]
		var img := Image.new()
		var err := FAILED
		if bytes.size() > 4 and bytes[0] == 0x89 and bytes[1] == 0x50:
			err = img.load_png_from_buffer(bytes)
		elif bytes.size() > 3 and bytes[0] == 0xFF and bytes[1] == 0xD8:
			err = img.load_jpg_from_buffer(bytes)
		elif bytes.size() > 12 and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
			err = img.load_webp_from_buffer(bytes)
		if err == OK:
			tex = ImageTexture.create_from_image(img)
	var waiting: Array = _avatars[key]
	_avatars[key] = tex
	for cb in waiting:
		if cb.is_valid():
			cb.call(tex)


# ── The page around the game ──

## The challenge in the page's address (?challenge=ID), once.
func challenge_in_address() -> String:
	return str(bridge.takeChallenge()) if is_web() else ""


func set_title(text: String) -> void:
	if is_web():
		bridge.setTitle(text)
	else:
		DisplayServer.window_set_title(text)


func copy(text: String) -> void:
	if is_web():
		bridge.copy(text)
	else:
		DisplayServer.clipboard_set(text)


## Asks Stockfish (in the page, web/bridge.ts) for a move at strength 1–8. Calls `done(uci)`;
## an empty string if the engine isn't available here.
func engine_move(moves: PackedStringArray, level: int, done: Callable) -> void:
	if not is_web():
		done.call("")
		return
	_engine_cb = JavaScriptBridge.create_callback(func(args: Array) -> void: done.call(str(args[0])))
	bridge.bestMove(" ".join(moves), level, _engine_cb)


func engine_cancel() -> void:
	if is_web():
		bridge.cancelEngine()


func engine_preload() -> void:
	if is_web():
		bridge.preloadEngine()


# ── The live connection to an online game ──

class Live:
	extends Node
	## Keeps a WebSocket to a game open, reconnecting with back-off, and emits every new state.
	signal state(game: Dictionary)
	signal connection(up: bool)

	var game_id := ""
	var ws := WebSocketPeer.new()
	var _retry := 0.5
	var _wait := 0.0
	var _ping := 0.0
	var _was_open := false
	var _said_down := false    ## whether connection(false) has been sent since the last time it was up

	func _init(id: String) -> void:
		game_id = id

	func _ready() -> void:
		_open()

	func _open() -> void:
		var url: String = Api.base.replace("https://", "wss://").replace("http://", "ws://") + "api/games/%s/live" % game_id
		ws = WebSocketPeer.new()
		if Api.token != "":
			ws.handshake_headers = PackedStringArray(["Authorization: Bearer " + Api.token])
		ws.connect_to_url(url)

	func _process(delta: float) -> void:
		if _wait > 0.0:
			_wait -= delta
			if _wait <= 0.0:
				_open()
			return
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				if not _was_open:
					_was_open = true
					_said_down = false
					_retry = 0.5
					connection.emit(true)
				_ping += delta
				if _ping > 25.0:
					_ping = 0.0
					ws.send_text("ping")
				while ws.get_available_packet_count() > 0:
					var msg: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
					if msg is Dictionary and msg.get("t") == "state":
						state.emit(msg.game)
			WebSocketPeer.STATE_CLOSED:
				# Down: after being open, or when even the first attempt fails.
				if not _said_down:
					_said_down = true
					connection.emit(false)
				_was_open = false
				_wait = _retry
				_retry = min(15.0, _retry * 2.0)

	func close() -> void:
		ws.close()
		set_process(false)
