extends Node3D
# A sliding window in the van's side wall. On load it cuts an opening out of the
# RV meshes (the model's wall is solid), then builds a frame and two glass panes
# in the gap. The sash can be slid open and shut with the interact key.

# Opening in the RV model's local space (the wall is the plane x = WALL_X)
const WALL_X := 79.0
const WALL_TOLERANCE := 10.0
const Z_MIN := -297.0
const Z_MAX := 83.0
const Y_MIN := -38.0
const Y_MAX := 68.0

const FRAME_THICKNESS := 0.012
const FRAME_DEPTH := 0.03
const PANE_GAP := 0.008 # distance between the fixed and the sliding pane
const SLIDE_TIME := 1.5

signal fully_opened

@export var rv_path: NodePath = ^"../RV"

var is_open := false
var fully_open := false
var width: float
var height: float
var sash: Node3D
var tween: Tween

func _ready() -> void:
	add_to_group("interactable")
	var rv: Node3D = get_node(rv_path)
	var scale_factor := rv.global_transform.basis.get_scale().x
	width = (Z_MAX - Z_MIN) * scale_factor
	height = (Y_MAX - Y_MIN) * scale_factor

	# Sit in the middle of the opening, facing out of the wall
	var center_local := Vector3(WALL_X, (Y_MIN + Y_MAX) / 2.0, (Z_MIN + Z_MAX) / 2.0)
	global_transform = Transform3D(rv.global_transform.basis.orthonormalized(), rv.global_transform * center_local)

	for mesh_instance in rv.find_children("*", "MeshInstance3D", true, false):
		var n := str(mesh_instance.name)
		if "Material" in n or "Glass" in n or "Metal" in n:
			_cut_opening(rv, mesh_instance)
	_build()

# --- window parts ----------------------------------------------------------

func _build() -> void:
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.82, 0.84, 0.86)
	frame_mat.metallic = 0.7
	frame_mat.roughness = 0.35

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.7, 0.85, 0.95, 0.18)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.05
	glass_mat.metallic_specular = 1.0

	var w := width
	var h := height
	var t := FRAME_THICKNESS
	# Frame: bars run along z (top/bottom) and y (sides); x is the wall normal
	_add_box(self, Vector3(FRAME_DEPTH, t, w + t * 2), Vector3(0, h / 2 + t / 2, 0), frame_mat)
	_add_box(self, Vector3(FRAME_DEPTH, t, w + t * 2), Vector3(0, -h / 2 - t / 2, 0), frame_mat)
	_add_box(self, Vector3(FRAME_DEPTH, h, t), Vector3(0, 0, w / 2 + t / 2), frame_mat)
	_add_box(self, Vector3(FRAME_DEPTH, h, t), Vector3(0, 0, -w / 2 - t / 2), frame_mat)
	# Sill that sticks out into the room
	_add_box(self, Vector3(0.05, t * 0.7, w + t * 4), Vector3(-0.012, -h / 2 - t * 1.3, 0), frame_mat)

	# Fixed pane on the +z half
	var pane_w := w / 2.0 + t * 0.5
	var fixed := Node3D.new()
	fixed.position = Vector3(PANE_GAP / 2, 0, w / 4 - t * 0.25)
	add_child(fixed)
	_add_box(fixed, Vector3(0.004, h, pane_w), Vector3.ZERO, glass_mat)
	_add_pane_frame(fixed, pane_w, frame_mat)

	# Sliding pane: starts closed on the -z half, slides over the fixed one
	sash = Node3D.new()
	sash.position = Vector3(-PANE_GAP / 2, 0, -w / 4 + t * 0.25)
	add_child(sash)
	_add_box(sash, Vector3(0.004, h, pane_w), Vector3.ZERO, glass_mat)
	_add_pane_frame(sash, pane_w, frame_mat)
	# Little handle on the sliding pane's inner edge
	_add_box(sash, Vector3(0.012, h * 0.28, 0.006), Vector3(-0.008, 0, pane_w / 2 - 0.02), frame_mat)

	# Invisible body the player's pickup ray can hit (layer 2 only, so it never
	# blocks movement)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.05, h, w)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.add_to_group("interactable")
	body.set_script(preload("res://Scripts/interactable_proxy.gd"))
	body.target = self

func _add_pane_frame(parent: Node3D, pane_w: float, mat: Material) -> void:
	var bar := 0.008
	_add_box(parent, Vector3(0.008, bar, pane_w), Vector3(0, height / 2 - bar / 2, 0), mat)
	_add_box(parent, Vector3(0.008, bar, pane_w), Vector3(0, -height / 2 + bar / 2, 0), mat)
	_add_box(parent, Vector3(0.008, height, bar), Vector3(0, 0, pane_w / 2 - bar / 2), mat)
	_add_box(parent, Vector3(0.008, height, bar), Vector3(0, 0, -pane_w / 2 + bar / 2), mat)

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)

# --- interaction -----------------------------------------------------------

func accepts_dish() -> bool:
	return fully_open

func get_prompt() -> String:
	return "[E] Close window" if is_open else "[E] Open window"

func interact() -> void:
	is_open = not is_open
	fully_open = false
	if tween:
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Open: the sliding pane travels over the fixed one, revealing the -z half
	var closed_z := -width / 4 + FRAME_THICKNESS * 0.25
	var open_z := width / 4 - FRAME_THICKNESS * 0.25
	tween.tween_property(sash, "position:z", open_z if is_open else closed_z, SLIDE_TIME)
	if is_open:
		tween.finished.connect(func():
			fully_open = true
			fully_opened.emit())

# --- cutting the hole ------------------------------------------------------

# Removes everything on the wall plane inside the opening. Triangles that
# straddle the edge are clipped, so the hole is exact.
func _cut_opening(rv: Node3D, mi: MeshInstance3D) -> void:
	var src := mi.mesh
	var to_rv: Transform3D = rv.global_transform.affine_inverse() * mi.global_transform
	var from_rv := to_rv.affine_inverse()
	var out := ArrayMesh.new()

	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var layout := _layout(arrays)
		var stride := 0
		for l in layout:
			stride += l[1]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var tri_count: int = idx.size() / 3 if idx else verts.size() / 3

		var flat := PackedFloat32Array()
		for t in tri_count:
			var tri: Array = []
			var all_on_wall := true
			var mn := Vector2(INF, INF)
			var mx := Vector2(-INF, -INF)
			for k in 3:
				var vi: int = idx[t * 3 + k] if idx else t * 3 + k
				var v := _vertex(arrays, layout, stride, vi)
				var p := to_rv * Vector3(v[0], v[1], v[2])
				v[0] = p.x; v[1] = p.y; v[2] = p.z
				tri.append(v)
				if absf(p.x - WALL_X) > WALL_TOLERANCE:
					all_on_wall = false
				mn = mn.min(Vector2(p.y, p.z))
				mx = mx.max(Vector2(p.y, p.z))
			var touches := all_on_wall and mx.x > Y_MIN and mn.x < Y_MAX and mx.y > Z_MIN and mn.y < Z_MAX
			var pieces: Array = [tri] if not touches else _subtract_rect(tri)
			for piece in pieces:
				for k in range(1, piece.size() - 1):
					for v in [piece[0], piece[k], piece[k + 1]]:
						var local := from_rv * Vector3(v[0], v[1], v[2])
						var copy: PackedFloat32Array = v.duplicate()
						copy[0] = local.x; copy[1] = local.y; copy[2] = local.z
						flat.append_array(copy)

		if flat.is_empty():
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _unpack(flat, layout, stride))
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
	mi.mesh = out

# Vertex attributes we carry through clipping: [array slot, float count]
func _layout(arrays: Array) -> Array:
	var layout: Array = [[Mesh.ARRAY_VERTEX, 3]]
	for entry in [[Mesh.ARRAY_NORMAL, 3], [Mesh.ARRAY_TANGENT, 4], [Mesh.ARRAY_COLOR, 4],
			[Mesh.ARRAY_TEX_UV, 2], [Mesh.ARRAY_TEX_UV2, 2]]:
		if arrays[entry[0]] != null and arrays[entry[0]].size() > 0:
			layout.append(entry)
	return layout

func _vertex(arrays: Array, layout: Array, stride: int, vi: int) -> PackedFloat32Array:
	var v := PackedFloat32Array()
	for l in layout:
		var a = arrays[l[0]]
		match l[0]:
			Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
				v.append_array([a[vi].x, a[vi].y, a[vi].z])
			Mesh.ARRAY_TANGENT:
				v.append_array([a[vi * 4], a[vi * 4 + 1], a[vi * 4 + 2], a[vi * 4 + 3]])
			Mesh.ARRAY_COLOR:
				v.append_array([a[vi].r, a[vi].g, a[vi].b, a[vi].a])
			_:
				v.append_array([a[vi].x, a[vi].y])
	return v

func _unpack(flat: PackedFloat32Array, layout: Array, stride: int) -> Array:
	var count := flat.size() / stride
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var offset := 0
	for l in layout:
		var slot: int = l[0]
		var size: int = l[1]
		match slot:
			Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
				var out := PackedVector3Array()
				for i in count:
					var o := i * stride + offset
					out.append(Vector3(flat[o], flat[o + 1], flat[o + 2]))
				arrays[slot] = out
			Mesh.ARRAY_TANGENT:
				var out := PackedFloat32Array()
				for i in count:
					var o := i * stride + offset
					out.append_array([flat[o], flat[o + 1], flat[o + 2], flat[o + 3]])
				arrays[slot] = out
			Mesh.ARRAY_COLOR:
				var out := PackedColorArray()
				for i in count:
					var o := i * stride + offset
					out.append(Color(flat[o], flat[o + 1], flat[o + 2], flat[o + 3]))
				arrays[slot] = out
			_:
				var out := PackedVector2Array()
				for i in count:
					var o := i * stride + offset
					out.append(Vector2(flat[o], flat[o + 1]))
				arrays[slot] = out
		offset += size
	return arrays

# The part of a triangle outside the opening, as convex polygons
func _subtract_rect(tri: Array) -> Array:
	var pieces: Array = []
	var left := _clip(tri, 2, Z_MIN, false)
	var right := _clip(tri, 2, Z_MAX, true)
	var middle := _clip(_clip(tri, 2, Z_MIN, true), 2, Z_MAX, false)
	var below := _clip(middle, 1, Y_MIN, false)
	var above := _clip(middle, 1, Y_MAX, true)
	for poly in [left, right, below, above]:
		if poly.size() >= 3:
			pieces.append(poly)
	return pieces

# Sutherland-Hodgman against one axis-aligned plane. keep_greater keeps the
# side where position[axis] >= value.
func _clip(poly: Array, axis: int, value: float, keep_greater: bool) -> Array:
	var out: Array = []
	for i in poly.size():
		var a: PackedFloat32Array = poly[i]
		var b: PackedFloat32Array = poly[(i + 1) % poly.size()]
		var a_in := (a[axis] >= value) if keep_greater else (a[axis] <= value)
		var b_in := (b[axis] >= value) if keep_greater else (b[axis] <= value)
		if a_in:
			out.append(a)
		if a_in != b_in:
			var f := (value - a[axis]) / (b[axis] - a[axis])
			var c := PackedFloat32Array()
			c.resize(a.size())
			for k in a.size():
				c[k] = lerpf(a[k], b[k], f)
			out.append(c)
	return out
