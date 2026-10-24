extends Node3D
# A door in the van's back wall (the LeftWall box), at the end away from the
# counters. Cream panel with maroon trim, corrugated lower half, a small
# window and steel hardware, so it picks up the van's palette.

const CREAM := Color(0.81, 0.76, 0.66)
const MAROON := Color(0.15, 0.075, 0.075)
const STEEL := Color(0.64, 0.64, 0.63)

const DOOR_SIZE := Vector2(0.26, 0.56)
const DOOR_X := 0.22 # wall-local x; +x points away from the counters
const FRAME := 0.014
const FRAME_DEPTH := 0.012

@export var back_wall_path: NodePath = ^"../LeftWall"

const MESSAGE_TIME := 1.6

var door_root: Node3D
var handle: Node3D
var rattle_tween: Tween
var message_label: Label
var message_tween: Tween

func _ready() -> void:
	var wall: CSGBox3D = get_node(back_wall_path)
	var base_y := -wall.size.y * 0.5
	var face_z := wall.size.z * 0.5
	var root := Node3D.new()
	root.position = Vector3(DOOR_X, base_y + DOOR_SIZE.y * 0.5, face_z)
	wall.add_child(root)
	door_root = root

	var w := DOOR_SIZE.x
	var h := DOOR_SIZE.y
	var paint := _mat(CREAM, 0.55)
	var trim := _mat(MAROON, 0.6)
	var steel := _mat(STEEL, 0.3, 0.7)
	var rib := _mat(Color(0.7, 0.68, 0.62), 0.5, 0.4)

	# Slab, then the frame around it
	_box(root, Vector3(w, h, 0.01), paint, Vector3(0, 0, 0.005))
	_box(root, Vector3(w + FRAME * 2, FRAME, FRAME_DEPTH), trim, Vector3(0, h * 0.5 + FRAME * 0.5, FRAME_DEPTH * 0.5))
	for side in [-1.0, 1.0]:
		_box(root, Vector3(FRAME, h + FRAME, FRAME_DEPTH), trim, Vector3(side * (w * 0.5 + FRAME * 0.5), FRAME * 0.5, FRAME_DEPTH * 0.5))

	# Corrugated lower half, echoing the van's walls
	for i in 9:
		_box(root, Vector3(w - 0.03, 0.007, 0.004), rib, Vector3(0, -h * 0.5 + 0.035 + i * 0.0225, 0.012))
	# Kick plate
	_box(root, Vector3(w, 0.03, 0.012), trim, Vector3(0, -h * 0.5 + 0.015, 0.006))

	# Window in the upper half, set in a trim frame
	var win := Vector2(0.14, 0.15)
	var win_y := h * 0.5 - 0.125
	_box(root, Vector3(win.x + 0.016, win.y + 0.016, 0.012), trim, Vector3(0, win_y, 0.006))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.45, 0.62, 0.75, 0.55)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	_box(root, Vector3(win.x, win.y, 0.002), glass, Vector3(0, win_y, 0.0135))

	# Lever handle and deadbolt on the side away from the hinges
	var hx := -w * 0.5 + 0.03
	# (the lever sits on a pivot so it can be rattled)
	handle = Node3D.new()
	handle.position = Vector3(hx, -0.03, 0)
	root.add_child(handle)
	_box(handle, Vector3(0.022, 0.07, 0.004), steel, Vector3(0, 0, 0.012))
	_cylinder(handle, 0.0065, 0.014, steel, Vector3(0, 0, 0.018), Vector3(90, 0, 0))
	_box(handle, Vector3(0.05, 0.007, 0.007), steel, Vector3(0.0225, 0, 0.0245))
	_cylinder(root, 0.006, 0.01, steel, Vector3(hx, 0.02, 0.016), Vector3(90, 0, 0))

	# Hinges
	for y in [-h * 0.5 + 0.08, 0.0, h * 0.5 - 0.08]:
		_cylinder(root, 0.004, 0.034, steel, Vector3(w * 0.5, y, FRAME_DEPTH + 0.002), Vector3.ZERO)

	# A small lamp over the door so the corner isn't pitch black
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.62)
	lamp.light_energy = 0.18
	lamp.omni_range = 0.7
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, h * 0.5 + 0.12, 0.2)
	root.add_child(lamp)

	# Invisible body the player's pickup ray can hit (layer 2 only, so it never
	# blocks movement)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, 0.06)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, 0, 0.03)
	root.add_child(body)
	body.add_to_group("interactable")
	body.set_script(preload("res://Scripts/interactable_proxy.gd"))
	body.target = self

	# On-screen message, shown when the player tries the door
	var layer := CanvasLayer.new()
	message_label = Label.new()
	message_label.text = "Dang. I guess I'm locked in"
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_label.offset_top = -160
	message_label.offset_bottom = -120
	UIStyle.style_label(message_label, UIStyle.SIZE_BODY)
	message_label.modulate.a = 0.0
	layer.add_child(message_label)
	add_child(layer)

# --- interaction -----------------------------------------------------------

func get_prompt() -> String:
	return "[E] Open door"

# The door is locked: jiggle the handle and shake the slab a touch, never open
func interact() -> void:
	if rattle_tween:
		rattle_tween.kill()
	handle.rotation = Vector3.ZERO
	door_root.rotation = Vector3.ZERO
	rattle_tween = create_tween()
	for i in 3:
		rattle_tween.tween_property(handle, "rotation:z", deg_to_rad(-22), 0.05)
		rattle_tween.parallel().tween_property(door_root, "rotation:y", deg_to_rad(0.8), 0.05)
		rattle_tween.tween_property(handle, "rotation:z", 0.0, 0.07)
		rattle_tween.parallel().tween_property(door_root, "rotation:y", 0.0, 0.07)

	if message_tween:
		message_tween.kill()
	message_label.modulate.a = 1.0
	message_tween = create_tween()
	message_tween.tween_interval(MESSAGE_TIME)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.4)

func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _cylinder(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
