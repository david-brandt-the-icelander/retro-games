@tool
extends EditorScenePostImport
## Turns a ship GLB into a rigged ship (docs/DESIGN.md § Rig contract): copies each node's glTF
## extras (kind, axis, amount, sign) into node metadata the ship script reads, moves textures
## baked on the second UV set to the first (the Cheetah's are; Godot's material reads the
## first), and turns the ship from +X forward to Godot's -Z forward.

func _post_import(scene: Node) -> Object:
	var parts := 0
	for node in _all_nodes(scene):
		var extras = node.get_meta("extras") if node.has_meta("extras") else null
		if extras is Dictionary and extras.has("kind"):
			for key in extras:
				node.set_meta("rig_" + str(key), extras[key])
			parts += 1
	scene.set_meta("rig_parts", parts)
	var root_extras = scene.get_meta("extras") if scene.has_meta("extras") else {}
	if bool(root_extras.get("textures_on_uv2", true)):
		for node in _all_nodes(scene):
			if node is MeshInstance3D:
				_use_second_uv_set(node)
	if scene is Node3D:
		(scene as Node3D).rotate_y(PI / 2.0)
	return scene


func _use_second_uv_set(instance: MeshInstance3D) -> void:
	var source := instance.mesh as ArrayMesh
	if source == null:
		return
	var rebuilt := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_TEX_UV2] != null:
			arrays[Mesh.ARRAY_TEX_UV] = arrays[Mesh.ARRAY_TEX_UV2]
			arrays[Mesh.ARRAY_TEX_UV2] = null
		rebuilt.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		rebuilt.surface_set_material(surface, source.surface_get_material(surface))
	rebuilt.resource_name = source.resource_name
	instance.mesh = rebuilt


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children():
		out.append_array(_all_nodes(child))
	return out
