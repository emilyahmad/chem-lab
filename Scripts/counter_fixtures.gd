extends Node3D
# A gooseneck faucet and a gas tap bolted to the van wall at the end of the
# counter, built from primitives. Local x points out of the wall, z runs along it.

const COUNTER_TOP_Y := 0.361
const WALL_POINT := Vector3(0.095, COUNTER_TOP_Y, 0.68) # on the wall, between the two fixtures

@export var rv_path: NodePath = ^"../RV"

func _ready() -> void:
	var rv: Node3D = get_node(rv_path)
	global_transform = Transform3D(rv.global_transform.basis.orthonormalized(), WALL_POINT)

	var steel := _material(Color(0.78, 0.8, 0.82), 0.3, 0.3)
	var brass := _material(Color(0.8, 0.6, 0.25), 0.4, 0.35)
	var red := _material(Color(0.75, 0.08, 0.06), 0.0, 0.5)

	# Gooseneck faucet: base, riser, arm over the counter, spout, handle
	var f := Vector3(-0.03, 0, -0.07)
	_cylinder(f + Vector3(0, 0.006, 0), 0.009, 0.012, Vector3.ZERO, steel)
	_cylinder(f + Vector3(0, 0.05, 0), 0.0035, 0.088, Vector3.ZERO, steel)
	_cylinder(f + Vector3(-0.0175, 0.094, 0), 0.0035, 0.04, Vector3(0, 0, 90), steel)
	_cylinder(f + Vector3(-0.035, 0.084, 0), 0.004, 0.02, Vector3.ZERO, steel)
	_cylinder(f + Vector3(0, 0.02, 0.012), 0.002, 0.02, Vector3(90, 0, 0), steel)
	_cylinder(f + Vector3(0, 0.03, 0.022), 0.005, 0.006, Vector3(90, 0, 0), red)

	# Gas tap: stub on the wall, nozzle pointing into the room, red valve knob
	var g := Vector3(-0.012, 0.06, 0.06)
	_cylinder(g, 0.009, 0.024, Vector3(0, 0, 90), brass)
	_cylinder(g + Vector3(-0.022, 0, 0), 0.0035, 0.03, Vector3(0, 0, 90), brass)
	_cylinder(g + Vector3(-0.012, 0.014, 0), 0.0025, 0.02, Vector3.ZERO, brass)
	_cylinder(g + Vector3(-0.012, 0.026, 0), 0.008, 0.005, Vector3.ZERO, red)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func _cylinder(pos: Vector3, radius: float, height: float, rot_deg: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
