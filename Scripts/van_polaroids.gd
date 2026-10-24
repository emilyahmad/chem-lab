extends Node3D
# Six polaroids pinned in the gaps between the posters, overlapping their edges
# a little: three on the van's front wall and three on the back wall (the
# LeftWall box). Each is a textured quad with a thin dark backing and a bit of
# tape, tilted slightly so they look hand-stuck.

const PHOTO_SIZE := Vector2(0.09, 0.11) # matches the 525 x 640 images
const LAYER := 0.0008
const OVER_POSTER := LAYER * 6 # lifts them off the wall so they sit in front of any poster they overlap

const FRONT_Z := -315.5 # front wall plane in the RV model's local space, nudged into the room
# [RV-local x, RV-local y, tilt in degrees]
const FRONT_SPOTS := [
	[-28.6, 38.0, -4.0],
	[29.0, 58.0, 3.0],
	[29.0, 14.0, -2.5],
]
# [wall-local x, wall-local y, tilt in degrees]
const BACK_SPOTS := [
	[-0.21, 0.26, 4.0],
	[-0.21, 0.01, -3.0],
	[-0.068, 0.13, 2.5],
]

@export var rv_path: NodePath = ^"../RV"
@export var back_wall_path: NodePath = ^"../LeftWall"
@export var posters_path: NodePath = ^"../VanPosters" # owns the enlarged view

func _ready() -> void:
	var rv: Node3D = get_node(rv_path)
	var s := rv.global_transform.basis.get_scale().x
	var front := Node3D.new()
	add_child(front)
	front.global_transform = Transform3D(rv.global_transform.basis.orthonormalized(), rv.global_transform * Vector3(0, 0, FRONT_Z))
	for i in FRONT_SPOTS.size():
		var spot: Array = FRONT_SPOTS[i]
		_polaroid(front, i + 1, Vector3(spot[0] * s, spot[1] * s, OVER_POSTER), spot[2])

	var back: CSGBox3D = get_node(back_wall_path)
	var z := back.size.z * 0.5 + LAYER
	for i in BACK_SPOTS.size():
		var spot: Array = BACK_SPOTS[i]
		_polaroid(back, FRONT_SPOTS.size() + i + 1, Vector3(spot[0], spot[1], z + OVER_POSTER), spot[2])

func _mat(color: Color, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if tex:
		m.albedo_texture = tex
	if tex:
		# unshaded so the photo shows its true colours, unaffected by room lighting
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _quad(parent: Node3D, size: Vector2, mat: StandardMaterial3D, pos: Vector3, rot_deg := 0.0) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.z = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _polaroid(parent: Node3D, index: int, pos: Vector3, tilt_deg: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.z = tilt_deg
	parent.add_child(root)
	var tex: Texture2D = load("res://images/Polaroids/polaroid_%d.png" % index)
	_quad(root, PHOTO_SIZE, _mat(Color.WHITE, tex), Vector3(0, 0, LAYER))
	_quad(root, Vector2(0.024, 0.009), _mat(Color(0.95, 0.9, 0.6)), Vector3(0, PHOTO_SIZE.y * 0.5, LAYER * 3), 0.0)
	var posters: Node = get_node(posters_path)
	posters.add_viewable(root, PHOTO_SIZE, tex, tilt_deg, LAYER * 2, "polaroid")
