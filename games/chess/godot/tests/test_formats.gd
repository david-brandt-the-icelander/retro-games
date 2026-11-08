extends SceneTree
## Run with: godot --headless --path godot -s tests/test_formats.gd
## Checks the text formats of docs/UI-DESIGN.md ("Formats"): durations, "… ago", day headings,
## clock times, move counts, records and move numbers.

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func matches(text: String, pattern: String) -> bool:
	var re := RegEx.create_from_string("^" + pattern + "$")
	return re.search(text) != null


func _init() -> void:
	# How long a move took: Ns · Nm SSs · Nh MMm · Nd Nh
	check(UI.duration(9_000) == "9s", "duration 9s")
	check(UI.duration(125_000) == "2m 05s", "duration 2m 05s")
	check(UI.duration((4 * 3600 + 37 * 60) * 1000.0) == "4h 37m", "duration 4h 37m")
	check(UI.duration((2 * 86400 + 4 * 3600 + 120) * 1000.0) == "2d 4h", "duration 2d 4h")

	# How long ago: just now · N min ago · N h ago · D Mon, HH:MM (with the year if not this year)
	var now := Time.get_unix_time_from_system() * 1000.0
	check(UI.ago(now - 20_000) == "just now", "ago: just now")
	check(UI.ago(now - 44 * 60_000) == "44 min ago", "ago: 44 min ago")
	check(UI.ago(now - 3 * 3600_000 - 60_000) == "3 h ago", "ago: 3 h ago")
	var three_days := UI.ago(now - 3 * 86400_000.0)
	check(matches(three_days, "\\d{1,2} [A-Z][a-z]{2}( \\d{4})?, \\d\\d:\\d\\d"), "ago: a date: %s" % three_days)
	var last_year := UI.ago(now - 400 * 86400_000.0)
	check(matches(last_year, "\\d{1,2} [A-Z][a-z]{2} \\d{4}, \\d\\d:\\d\\d"), "ago: another year has its year: %s" % last_year)

	# Clock times and day headings
	check(matches(UI.hhmm(now), "\\d\\d:\\d\\d"), "clock time HH:MM: %s" % UI.hhmm(now))
	check(UI.day(now) == "Today", "day: Today")
	check(UI.day(now - 86400_000.0) == "Yesterday", "day: Yesterday")
	var old_day := UI.day(now - 400 * 86400_000.0)
	check(matches(old_day, "[A-Z][a-z]+day \\d{1,2} [A-Z][a-z]+ \\d{4}"), "day: another year has its year: %s" % old_day)

	# Moves, records, move numbers
	check(UI.moves_text(0) == "No moves yet", "no moves yet")
	check(UI.moves_text(1) == "1 move" and UI.moves_text(2) == "1 move", "1 move (one by each side)")
	check(UI.moves_text(7) == "4 moves", "4 moves")
	check(UI.record(1, 0, 0) == "1 win · 0 losses · 0 draws", "record, singular win")
	check(UI.record(2, 1, 1) == "2 wins · 1 loss · 1 draw", "record, mixed")
	check(UI.move_number(5) == "3." and UI.move_number(6) == "3…", "move numbers 3. and 3…")

	print("%d failures" % failures)
	quit(1 if failures else 0)
