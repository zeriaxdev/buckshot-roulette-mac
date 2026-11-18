extends SceneTree

func _initialize():
	var helper = load(OS.get_cmdline_user_args()[0]).new()
	var source := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.RIGHT + Vector3.FORWARD, Vector3.FORWARD])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	source.resource_name = "synthetic panel"
	source.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(3, 3, 3))
	source.lightmap_size_hint = Vector2i(64, 32)
	for i in range(2):
		source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		source.surface_set_material(i, StandardMaterial3D.new())
		source.surface_set_name(i, "surface %d" % i)
	var table := Node3D.new(); table.name = "tabletop parent"
	var body := MeshInstance3D.new(); body.name = "main tabletop"; body.mesh = source; table.add_child(body)
	var compartments := Node3D.new(); compartments.name = "compartments parent"; body.add_child(compartments)
	var targets := [body]
	for spec in [["main tabletop2", table], ["compartment user_briefcase", compartments], ["compartment 1", compartments], ["Plane_035", body], ["health counter", body]]:
		var node := MeshInstance3D.new(); node.name = spec[0]; node.mesh = source
		spec[1].add_child(node); targets.append(node)
	helper._walk(table)
	for node in targets:
		if node.mesh == source or source.has_meta("mac_table_mesh"):
			return fail("must replace instance meshes without modifying their shared source")
		if node.mesh.resource_name != source.resource_name or node.mesh.get_surface_count() != 2:
			return fail("mesh identity and surface count must survive")
		if node.mesh.custom_aabb != source.custom_aabb or node.mesh.lightmap_size_hint != source.lightmap_size_hint:
			return fail("custom bounds and lightmap sizing must survive")
		for i in range(2):
			if node.mesh.surface_get_arrays(i) != source.surface_get_arrays(i):
				return fail("geometry, normals, UVs and indices must survive")
			if node.mesh.surface_get_material(i) != source.surface_get_material(i):
				return fail("materials must survive")
			if node.mesh.surface_get_name(i) != source.surface_get_name(i):
				return fail("surface names must survive")
		var fixed = node.mesh
		helper._on_node_added(node)
		if node.mesh != fixed:
			return fail("resizing must not keep rebuilding a mesh")
	var other := MeshInstance3D.new()
	other.name = "another mesh"
	other.mesh = source
	compartments.add_child(other)
	helper._fit(other)
	if other.mesh != source:
		return fail("unrelated meshes must stay unchanged")
	var lod_mesh := ArrayMesh.new()
	lod_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {1.0: PackedInt32Array([0, 1, 2])})
	other.name = "compartment future"; other.mesh = lod_mesh
	helper._fit(other)
	if other.mesh == lod_mesh or other.mesh.get("_surfaces")[0]["lods"] != lod_mesh.get("_surfaces")[0]["lods"]:
		return fail("rebuilding must retain the exact LOD distances and index bytes")
	other.mesh = source; other.skin = Skin.new()
	helper._fit(other)
	if other.mesh != source:
		return fail("animated meshes must be left unchanged")
	table.free(); helper.free()
	print("PASS table geometry: 6 target parts preserved; source unchanged; applied once; unrelated meshes and LODs retained")
	quit()

func fail(message: String):
	printerr("FAIL table geometry: ", message)
	quit(1)
