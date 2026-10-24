extends RigidBody3D
# A plain cube. The origin is the middle of the base, so it sits on the counter
# at the counter-top height.

const SIZE := 0.04

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.55, 0.7)
	mat.roughness = 0.6

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * SIZE
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(0, SIZE / 2.0, 0)
	add_child(mi)
