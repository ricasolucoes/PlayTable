extends SceneTree
func _check(name: String, mesh: Mesh) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var ag := 0; var dis := 0
	if idx.size() > 0:
		for i in range(0, idx.size(), 3):
			var a := verts[idx[i]]; var b := verts[idx[i+1]]; var c := verts[idx[i+2]]
			var geo := (b-a).cross(c-a)
			if geo.length() < 1e-9: continue
			var avg := (norms[idx[i]]+norms[idx[i+1]]+norms[idx[i+2]]).normalized()
			if geo.normalized().dot(avg) > 0.0: ag += 1
			else: dis += 1
	print("%s: agree=%d disagree=%d (indexed=%s)" % [name, ag, dis, idx.size() > 0])
func _initialize() -> void:
	var b := BoxMesh.new(); b.size = Vector3.ONE
	_check("BoxMesh", b)
	var c := CylinderMesh.new()
	_check("CylinderMesh", c)
	quit(0)
