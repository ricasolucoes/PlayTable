extends SceneTree
func _initialize() -> void:
	var mesh := MeshBuilder3D.disc_token(0.30, 0.13)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var agree := 0
	var disagree := 0
	var degenerate := 0
	for i in range(0, verts.size(), 3):
		var a := verts[i]; var b := verts[i+1]; var c := verts[i+2]
		var geo := (b - a).cross(c - a)
		if geo.length() < 1e-9:
			degenerate += 1
			continue
		geo = geo.normalized()
		var avg := (norms[i] + norms[i+1] + norms[i+2]).normalized()
		if geo.dot(avg) > 0.0: agree += 1
		else: disagree += 1
	print("disc: tris=%d agree=%d disagree=%d degenerate=%d" % [verts.size()/3, agree, disagree, degenerate])

	var rb := MeshBuilder3D.rounded_box(Vector3(0.5,0.5,0.5), 0.07, 3)
	var a2 := rb.surface_get_arrays(0)
	var v2: PackedVector3Array = a2[Mesh.ARRAY_VERTEX]
	var n2: PackedVector3Array = a2[Mesh.ARRAY_NORMAL]
	var ag2 := 0; var dis2 := 0; var deg2 := 0
	for i in range(0, v2.size(), 3):
		var geo := (v2[i+1] - v2[i]).cross(v2[i+2] - v2[i])
		if geo.length() < 1e-9:
			deg2 += 1
			continue
		if geo.normalized().dot((n2[i]+n2[i+1]+n2[i+2]).normalized()) > 0.0: ag2 += 1
		else: dis2 += 1
	print("roundedbox: tris=%d agree=%d disagree=%d degenerate=%d" % [v2.size()/3, ag2, dis2, deg2])
	quit(0)
