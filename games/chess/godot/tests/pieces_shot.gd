extends SceneTree
## Renders every piece in a row, for looking at the models:
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
	root.add_child(sun)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("ece6d8")
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
			m.position = Vector3(i * 0.9 - 2.25, 0, c * -1.0)
			if i + 1 == Chess.KNIGHT:
				m.rotation.y = deg_to_rad(-38) if c == 0 else deg_to_rad(-142)
			root.add_child(m)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 5.6)
	cam.fov = 40
	root.add_child(cam)
	cam.look_at(Vector3(0, 0.5, -0.5))
	for i in 5:
		await process_frame
	var out := "/tmp/pieces.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	get_root().get_texture().get_image().save_png(out)
	quit()
