extends Node3D
# Six posters (images/Posters), three on each short wall of the van. The front
# wall is part of the RV model (so the posters follow the RV's frame); the back
# wall is the LeftWall box, so those posters are parented to it.

# Front wall plane in the RV model's local space, nudged into the room
const FRONT_Z := -315.5
const POSTER_Y := 28.0 # RV-local height of the poster centres (above the counter top)
const POSTER_SPACING := 56.0 # RV-local distance between front posters
const LAYER := 0.0008 # gap between stacked layers, so they don't z-fight

const FRONT_POSTERS := ["poster_1", "poster_2", "poster_3"]
const BACK_POSTERS := ["poster_4", "poster_5", "poster_6"]

# Hand-stuck wobble per poster: [x shift, y shift, tilt in degrees]. Front shifts
# are in metres at the RV's scale; back ones are in the wall's local metres.
const FRONT_WOBBLE := [[-0.006, 0.008, -3.5], [0.004, -0.01, 2.5], [0.007, 0.006, -2.0]]
const BACK_WOBBLE := [[0.004, -0.006, 3.0], [-0.003, 0.01, -2.5], [-0.004, -0.004, 2.0]]

@export var rv_path: NodePath = ^"../RV"
@export var back_wall_path: NodePath = ^"../LeftWall"

func _ready() -> void:
	var rv: Node3D = get_node(rv_path)
	var s := rv.global_transform.basis.get_scale().x
	var front := Node3D.new()
	add_child(front)
	front.global_transform = Transform3D(rv.global_transform.basis.orthonormalized(), rv.global_transform * Vector3(0, 0, FRONT_Z))
	for i in 3:
		var w: Array = FRONT_WOBBLE[i]
		_poster(front, FRONT_POSTERS[i], Vector3((i - 1) * POSTER_SPACING * s + w[0], POSTER_Y * s + w[1], 0), 0.2, w[2])

	# Back wall: the door takes the -x end, so the posters sit in the remaining
	# run (the wall's local +x points away from the counters).
	var back: CSGBox3D = get_node(back_wall_path)
	var z := back.size.z * 0.5 + LAYER
	for i in 3:
		var w: Array = BACK_WOBBLE[i]
		_poster(back, BACK_POSTERS[i], Vector3(-0.29 + i * 0.15 + w[0], 0.13 + w[1], z), 0.17, w[2])

# A poster image of the given height (width follows the image) with tape at the top corners
func _poster(parent: Node3D, image: String, pos: Vector3, height: float, tilt_deg: float) -> void:
	var tex: Texture2D = load("res://images/Posters/%s.png" % image)
	var size := Vector2(height * tex.get_width() / tex.get_height(), height)
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.z = tilt_deg
	parent.add_child(root)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# a touch of emission keeps the posters legible in the dim corners
	mat.emission_enabled = true
	mat.emission_texture = tex
	mat.emission_energy_multiplier = 0.12
	_quad(root, size, mat, Vector3.ZERO)

	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(0.95, 0.9, 0.6)
	tape.cull_mode = BaseMaterial3D.CULL_DISABLED
	for c in [-1.0, 1.0]:
		_quad(root, Vector2(0.026, 0.01), tape, Vector3(c * size.x * 0.5, size.y * 0.5, LAYER * 3), -45.0 * c)

func _quad(parent: Node3D, size: Vector2, mat: Material, pos: Vector3, rot_deg := 0.0) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.z = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
