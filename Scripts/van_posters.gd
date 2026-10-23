extends Node3D
# Six chemistry posters, three on each short wall of the van, built from
# quads, discs and Label3Ds. The front wall is part of the RV model (so the
# posters follow the RV's frame); the back wall is the LeftWall box, so those
# posters are parented to it.

const FONT := preload("res://Assets/UI/Fonts/Cooper Lt BT W08 Regular.ttf")

# Front wall plane in the RV model's local space, nudged into the room
const FRONT_Z := -315.5
const POSTER_Y := 15.0 # RV-local height of the poster centres (above the counter top)
const LAYER := 0.0008 # gap between stacked layers, so they don't z-fight

const CREAM := Color(0.93, 0.88, 0.76)
const MAROON := Color(0.24, 0.1, 0.1)
const INK := Color(0.16, 0.09, 0.08)

const CATEGORIES := {
	"alkali": ["Li", "Na", "K"],
	"alkaline": ["Be", "Mg", "Ca"],
	"metalloid": ["B", "Si", "Ge", "As"],
	"post": ["Al", "Ga"],
	"nonmetal": ["H", "C", "N", "O", "P", "S", "Se"],
	"halogen": ["F", "Cl", "Br"],
	"noble": ["He", "Ne", "Ar", "Kr"],
}
const CATEGORY_COLORS := {
	"alkali": Color(0.9, 0.36, 0.3),
	"alkaline": Color(0.95, 0.62, 0.26),
	"metalloid": Color(0.4, 0.76, 0.66),
	"post": Color(0.6, 0.8, 0.45),
	"nonmetal": Color(0.45, 0.7, 0.95),
	"halogen": Color(0.72, 0.56, 0.9),
	"noble": Color(0.95, 0.6, 0.8),
	"transition": Color(0.95, 0.85, 0.45),
}

@export var rv_path: NodePath = ^"../RV"
@export var back_wall_path: NodePath = ^"../LeftWall"

func _ready() -> void:
	var rv: Node3D = get_node(rv_path)
	var s := rv.global_transform.basis.get_scale().x
	var front := Node3D.new()
	add_child(front)
	front.global_transform = Transform3D(rv.global_transform.basis.orthonormalized(), rv.global_transform * Vector3(0, 0, FRONT_Z))
	var front_size := Vector2(0.15, 0.2)
	for i in 3:
		var p := _paper(front, Vector3((i - 1) * 50.0 * s, POSTER_Y * s, 0), front_size, [CREAM, MAROON, CREAM][i])
		[_periodic_table, _argon_joke, _ph_scale][i].call(p, front_size)

	# Back wall: the door takes the -x end, so the posters sit in the remaining
	# run (the wall's local +x points away from the counters).
	var back: CSGBox3D = get_node(back_wall_path)
	var back_size := Vector2(0.13, 0.17)
	var z := back.size.z * 0.5 + LAYER
	for i in 3:
		var p := _paper(back, Vector3(-0.285 + i * 0.145, 0.089, z), back_size, [Color(0.78, 0.9, 0.92), Color(0.98, 0.82, 0.2), CREAM][i])
		[_atom_trust, _lab_safety, _precipitate][i].call(p, back_size)

# --- building blocks -------------------------------------------------------

func _mat(color: Color, glow := 0.12) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	# a touch of emission keeps the posters legible in the dim corners
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = glow
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _quad(parent: Node3D, size: Vector2, color: Color, pos: Vector3, rot_deg := 0.0) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mesh.material = _mat(color)
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.z = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _disc(parent: Node3D, radius: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.0002
	mesh.radial_segments = 20
	mesh.rings = 1
	mesh.material = _mat(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.x = 90
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

# Convex polygon in the poster's plane
func _poly(parent: Node3D, points: Array, color: Color, z: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	for i in range(1, points.size() - 1):
		for p in [points[0], points[i + 1], points[i]]:
			st.add_vertex(Vector3(p.x, p.y, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.mesh.surface_set_material(0, _mat(color))
	mi.position.z = z
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _label(parent: Node3D, text: String, pos: Vector3, font_size: int, color: Color, width_px := 0.0, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = font_size
	l.pixel_size = 0.0004
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.horizontal_alignment = align
	if width_px > 0.0:
		l.width = width_px
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = pos
	parent.add_child(l)
	return l

# A poster: dark backing, paper and four strips of tape. Returns the paper
# node; contents are added to it at z offsets of LAYER.
func _paper(parent: Node3D, pos: Vector3, size: Vector2, color: Color) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	_quad(root, size + Vector2(0.006, 0.006), Color(0.1, 0.07, 0.06), Vector3.ZERO)
	_quad(root, size, color, Vector3(0, 0, LAYER))
	for c in [Vector2(-1, 1), Vector2(1, 1)]:
		_quad(root, Vector2(0.026, 0.01), Color(0.95, 0.9, 0.6), Vector3(c.x * size.x * 0.5, c.y * size.y * 0.5, LAYER * 3), -45.0 * c.x * c.y)
	return root

func _px(poster_size: Vector2) -> float:
	return poster_size.x / 0.0004

# --- front wall ------------------------------------------------------------

func _periodic_table(p: Node3D, size: Vector2) -> void:
	_label(p, "PERIODIC TABLE", Vector3(0, size.y * 0.5 - 0.022, LAYER * 2), 40, INK)
	var rows := [
		_row(["H"], ["He"]),
		_row(["Li", "Be"], ["B", "C", "N", "O", "F", "Ne"]),
		_row(["Na", "Mg"], ["Al", "Si", "P", "S", "Cl", "Ar"]),
		["K", "Ca", "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "As", "Se", "Br", "Kr"],
	]
	var cell := (size.x - 0.014) / 18.0
	var origin := Vector2(-size.x * 0.5 + 0.007 + cell * 0.5, size.y * 0.5 - 0.075)
	for r in rows.size():
		for c in 18:
			var sym: String = rows[r][c]
			if sym == "":
				continue
			var at := origin + Vector2(c * cell, -r * cell)
			_quad(p, Vector2(cell * 0.92, cell * 0.92), _element_color(sym), Vector3(at.x, at.y, LAYER * 2))
			_label(p, sym, Vector3(at.x, at.y, LAYER * 3), 30, INK).pixel_size = 0.00012
	_label(p, "Elements 1 to 36\nKnow your atoms!", Vector3(0, -size.y * 0.5 + 0.03, LAYER * 2), 28, INK)

func _row(left: Array, right: Array) -> Array:
	var out := []
	out.append_array(left)
	for i in 18 - left.size() - right.size():
		out.append("")
	out.append_array(right)
	return out

func _element_color(sym: String) -> Color:
	for k in CATEGORIES:
		if sym in CATEGORIES[k]:
			return CATEGORY_COLORS[k]
	return CATEGORY_COLORS["transition"]

func _argon_joke(p: Node3D, size: Vector2) -> void:
	var cream := CREAM
	_label(p, "I'd tell you a chemistry joke...", Vector3(0, size.y * 0.5 - 0.035, LAYER * 2), 38, cream, _px(size) * 0.82)
	# Element tile
	_quad(p, Vector2(0.075, 0.075), Color(0.95, 0.6, 0.8), Vector3(0, -0.015, LAYER * 2))
	_quad(p, Vector2(0.069, 0.069), Color(0.97, 0.78, 0.88), Vector3(0, -0.015, LAYER * 3))
	_label(p, "18", Vector3(-0.026, 0.0, LAYER * 4), 30, INK)
	_label(p, "Ar", Vector3(0, -0.012, LAYER * 4), 96, INK)
	_label(p, "Argon", Vector3(0, -0.04, LAYER * 4), 36, INK)
	_label(p, "...but all the good ones Argon.", Vector3(0, -size.y * 0.5 + 0.032, LAYER * 2), 38, cream, _px(size) * 0.82)

func _ph_scale(p: Node3D, size: Vector2) -> void:
	_label(p, "pH SCALE", Vector3(0, size.y * 0.5 - 0.024, LAYER * 2), 48, INK)
	var w := (size.x - 0.02) / 15.0
	for i in 15:
		var x := -size.x * 0.5 + 0.01 + w * (i + 0.5)
		_quad(p, Vector2(w, 0.05), Color.from_hsv(lerpf(0.0, 0.75, i / 14.0), 0.75, 0.95), Vector3(x, 0.02, LAYER * 2))
	for stop in [[0, "0"], [7, "7"], [14, "14"]]:
		_label(p, stop[1], Vector3(-size.x * 0.5 + 0.01 + w * (stop[0] + 0.5), -0.015, LAYER * 2), 36, INK)
	_label(p, "ACID", Vector3(-size.x * 0.5 + 0.026, -0.03, LAYER * 2), 26, INK)
	_label(p, "NEUTRAL", Vector3(0, -0.03, LAYER * 2), 26, INK)
	_label(p, "BASE", Vector3(size.x * 0.5 - 0.026, -0.03, LAYER * 2), 26, INK)
	_label(p, "Acid jokes?\nToo basic.", Vector3(0, -size.y * 0.5 + 0.04, LAYER * 2), 44, INK)

# --- back wall -------------------------------------------------------------

func _atom_trust(p: Node3D, size: Vector2) -> void:
	_label(p, "NEVER TRUST AN ATOM", Vector3(0, size.y * 0.5 - 0.022, LAYER * 2), 30, INK, _px(size) * 0.9)
	var center := Vector3(0, 0.005, LAYER * 2)
	var orbit_mat := _mat(Color(0.2, 0.3, 0.45))
	for i in 3:
		var pivot := Node3D.new()
		pivot.position = center
		pivot.rotation_degrees.z = i * 60.0
		p.add_child(pivot)
		var flat := Node3D.new()
		flat.scale = Vector3(1, 0.4, 1)
		pivot.add_child(flat)
		var torus := TorusMesh.new()
		torus.outer_radius = 0.0475
		torus.inner_radius = 0.0455
		torus.rings = 40
		torus.ring_segments = 6
		torus.material = orbit_mat
		var mi := MeshInstance3D.new()
		mi.mesh = torus
		mi.rotation_degrees.x = 90
		mi.scale.y = 0.05
		flat.add_child(mi)
		_disc(flat, 0.0045, Color(0.2, 0.55, 0.95), Vector3(0.0465 * cos(i * 2.1), 0.0465 * sin(i * 2.1), 0))
	_disc(p, 0.009, Color(0.85, 0.2, 0.2), center + Vector3(0, 0, LAYER))
	_label(p, "They make up\nEVERYTHING.", Vector3(0, -size.y * 0.5 + 0.026, LAYER * 2), 34, INK)

func _lab_safety(p: Node3D, size: Vector2) -> void:
	var stripe_h := 0.014
	var n := 9
	var w := (size.x - 0.01) / n
	for edge in [1.0, -1.0]:
		var y: float = edge * (size.y * 0.5 - 0.012)
		for i in n:
			if i % 2 == 0:
				var x0 := -size.x * 0.5 + 0.005 + i * w
				_poly(p, [Vector2(x0, y - stripe_h * 0.5), Vector2(x0 + w, y - stripe_h * 0.5), Vector2(x0 + w + 0.006, y + stripe_h * 0.5), Vector2(x0 + 0.006, y + stripe_h * 0.5)], INK, LAYER * 2)
	_label(p, "LAB SAFETY", Vector3(0, size.y * 0.5 - 0.04, LAYER * 2), 44, INK)
	var lines := ["Goggles on", "No tasting", "No running", "Label it all"]
	for i in lines.size():
		var y := 0.03 - i * 0.024
		_disc(p, 0.0033, INK, Vector3(-size.x * 0.5 + 0.014, y, LAYER * 2))
		_label(p, lines[i], Vector3(-size.x * 0.5 + 0.024, y, LAYER * 2), 34, INK, 0.0, HORIZONTAL_ALIGNMENT_LEFT)

func _precipitate(p: Node3D, size: Vector2) -> void:
	_label(p, "Part of the solution,\nor the precipitate?", Vector3(0, size.y * 0.5 - 0.03, LAYER * 2), 30, INK)
	# Beaker with a clump settled at the bottom
	var bw := 0.032
	var bb := -0.05
	var top := 0.005
	_poly(p, [Vector2(-bw, bb), Vector2(bw, bb), Vector2(bw, top), Vector2(-bw, top)], Color(0.75, 0.88, 0.93), LAYER * 2)
	_poly(p, [Vector2(-bw + 0.003, bb + 0.003), Vector2(bw - 0.003, bb + 0.003), Vector2(bw - 0.003, top - 0.016), Vector2(-bw + 0.003, top - 0.016)], Color(0.3, 0.7, 0.9), LAYER * 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 14:
		_disc(p, rng.randf_range(0.0022, 0.004), Color(0.97, 0.97, 0.95), Vector3(rng.randf_range(-bw + 0.008, bw - 0.008), bb + 0.008 + rng.randf() * 0.005, LAYER * 4))
	_label(p, "(Don't be a precipitate.)", Vector3(0, -size.y * 0.5 + 0.018, LAYER * 2), 22, INK)
