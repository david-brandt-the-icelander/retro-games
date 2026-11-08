extends SceneTree
## Renders every piece in a row (docs/screens/23-pieces.png), for looking at the models:
## xvfb-run godot --rendering-driver opengl3 --path godot -s tests/pieces_shot.gd -- --out=/tmp/pieces.png

func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("15171c")
	env.ambient_light_color = Color("888888")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-4, 4, -5)
	rim.light_color = Color("8fb3ff")
	rim.light_energy = 1.4
	rim.omni_range = 22.0
	root.add_child(rim)
	root.add_child(sun)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("e0d8c6")
	white.roughness = 0.3
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("1d1e24")
	black.roughness = 0.18
	black.metallic = 0.35
	for i in 6:
		for c in 2:
			var m := MeshInstance3D.new()
			m.mesh = PieceMeshes.mesh(i + 1)
			m.material_override = white if c == 0 else black
			# One row: the white set, then the black set, each pawn to king.
			m.position = Vector3((c * 6 + i) * 0.82 - 4.51, 0, 0)
			if i + 1 == Chess.KNIGHT:
				m.rotation.y = deg_to_rad(38) if c == 0 else deg_to_rad(142)
			root.add_child(m)
	var cam := Camera3D.new()
	cam.fov = 34
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.4, 11.5), Vector3(0, 0.55, 0))
	for i in 5:
		await process_frame
	var out := "/tmp/pieces.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	get_root().get_texture().get_image().save_png(out)
	quit()
