extends RigidBody3D
# Dresses up an ingredient's plain white mesh: gives it a proper material and
# adds the details that make it read as the real object (liquid, labels, caps,
# markings...). Everything is built from primitives in the ingredient's own
# space, so it follows the item when it is picked up, enlarged or moved.
# Positions are in the units the models were measured in (see each builder).

@export_enum("beaker", "bowl", "coffee_filter", "erlenmeyer", "gas", "mixer", "petri_dish", "syringe") var kind := "beaker"

# Beaker only: when label_text is set the beaker gets a paper label with that
# text (on the side facing -x) and is filled with contents_color, as a powder
# mound if contents_powder is set, otherwise as liquid.
@export var label_text := ""
@export var contents_color := Color(1, 1, 1, 0)
@export var contents_powder := false

const GLASS := Color(0.78, 0.92, 1.0, 0.2)

func _ready() -> void:
	call("_build_" + kind)

# --- helpers ---------------------------------------------------------------

func _mesh_instance() -> MeshInstance3D:
	return find_children("*", "MeshInstance3D", false, false)[0]

func _mat(color: Color, roughness := 0.5, metallic := 0.0, priority := 0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = priority
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _glass(priority := 1) -> StandardMaterial3D:
	var m := _mat(GLASS, 0.05, 0.0, priority)
	m.metallic_specular = 1.0
	return m

func _add(mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _cyl(r_top: float, r_bottom: float, h: float, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = 24
	m.rings = 1
	return _add(m, mat, pos, rot_deg)

func _box(size: Vector3, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(m, mat, pos, rot_deg)

func _sphere(radius: float, mat: Material, pos: Vector3, squash_y := 1.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 * squash_y
	m.radial_segments = 24
	m.rings = 12
	return _add(m, mat, pos)

func _ring(outer: float, tube: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.outer_radius = outer
	m.inner_radius = outer - tube * 2.0
	m.rings = 32
	m.ring_segments = 8
	return _add(m, mat, pos)

# --- beaker: empty glass with graduation marks --------------------

func _build_beaker() -> void:
	_mesh_instance().material_override = _glass()
	var ink := _mat(Color(0.08, 0.08, 0.12), 0.6)
	for i in 6:
		var w := 0.014 if i % 2 == 0 else 0.008
		_box(Vector3(w, 0.0012, 0.0012), ink, Vector3(0, -0.012 + i * 0.0075, 0.0268))
	# Frosted writing patch on the side
	_box(Vector3(0.0008, 0.016, 0.013), _mat(Color(0.95, 0.97, 1.0), 0.8), Vector3(0.0268, -0.004, 0))
	if label_text != "":
		_beaker_contents()
		_beaker_label()

# Fill sits inside the glass (inner radius ~0.022, floor at y = -0.023)
func _beaker_contents() -> void:
	if contents_powder:
		var powder := _mat(contents_color, 0.95)
		_cyl(0.021, 0.021, 0.01, powder, Vector3(0, -0.018, 0))
		_sphere(0.021, powder, Vector3(0, -0.013, 0), 0.4)
	else:
		set_fill_ml(BEAKER_START_ML, contents_color)

# Liquid level, in mL of the beaker's 250 mL capacity. Any beaker can be filled, labeled or
# not; the liquid is built the first time it's needed.
const BEAKER_CAP_ML := 250.0
const BEAKER_START_ML := 220.0
const BEAKER_FLOOR_Y := -0.023
const BEAKER_FILL_H := 0.048 # inner height at capacity

var fill_ml := 0.0
var _liquid: MeshInstance3D

func set_fill_ml(ml: float, color := contents_color) -> void:
	fill_ml = clampf(ml, 0.0, BEAKER_CAP_ML)
	if _liquid == null:
		var mat := _mat(color, 0.05, 0.0, 0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_liquid = _cyl(0.021, 0.021, 0.001, mat, Vector3.ZERO)
	var h := fill_ml / BEAKER_CAP_ML * BEAKER_FILL_H
	_liquid.visible = h > 0.0003
	(_liquid.mesh as CylinderMesh).height = maxf(h, 0.001)
	_liquid.position.y = BEAKER_FLOOR_Y + h / 2.0

# Height of the liquid surface in the beaker's own space
func surface_y() -> float:
	return BEAKER_FLOOR_Y + fill_ml / BEAKER_CAP_ML * BEAKER_FILL_H

# Paper label stuck on the -x side with the name printed on it
func _beaker_label() -> void:
	_box(Vector3(0.0006, 0.016, 0.022), _mat(Color(0.97, 0.95, 0.88), 0.85), Vector3(-0.0262, 0.0, 0))
	var text := Label3D.new()
	text.text = label_text
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.font_size = 26
	text.pixel_size = 0.00014
	text.modulate = Color(0.1, 0.1, 0.15)
	text.outline_size = 0
	text.double_sided = false
	text.position = Vector3(-0.0266, 0.0, 0)
	text.rotation_degrees = Vector3(0, -90, 0)
	text.width = 150
	add_child(text)

# --- bowl: cream ceramic with a teal glaze band and gold rim ----------------
# The body is a lathe of a rounded profile (built here so its size is easy to
# tweak): bottom of the foot sits at y = -BOWL_DROP, where the old bowl rested.

const BOWL_R := 0.047       # rim radius
const BOWL_H := 0.05        # height
const BOWL_FOOT := 0.019    # foot ring radius
const BOWL_WALL := 0.0025   # wall thickness
const BOWL_DROP := 0.0406

func _bowl_wall_radius(y: float) -> float:
	return BOWL_R * sin(acos(clampf(1.0 - y / BOWL_H, -1.0, 1.0)))

func _bowl_mesh() -> ArrayMesh:
	var a0 := asin(BOWL_FOOT / BOWL_R)
	var steps := 14
	var pts: Array[Vector2] = []
	# inner floor centre -> up the inner wall
	for i in steps + 1:
		var a := lerpf(0.0, PI / 2.0, float(i) / steps)
		pts.append(Vector2((BOWL_R - BOWL_WALL) * sin(a), BOWL_WALL + (BOWL_H - BOWL_WALL) * (1.0 - cos(a))))
	# over the rim and down the outer wall to the foot
	for i in steps + 1:
		var a := lerpf(PI / 2.0, a0, float(i) / steps)
		pts.append(Vector2(BOWL_R * sin(a), BOWL_H * (1.0 - cos(a))))
	pts.append(Vector2(BOWL_FOOT, 0.0))
	pts.append(Vector2(0.0, 0.0))
	# per-point normals, averaged from the neighbouring profile segments
	var norms: Array[Vector2] = []
	for i in pts.size():
		var t := pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
		norms.append(Vector2(-t.y, t.x).normalized())
	var segs := 48
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in segs:
		var th0 := TAU * j / segs
		var th1 := TAU * (j + 1) / segs
		for i in pts.size() - 1:
			var corners := [[i, th0], [i + 1, th0], [i + 1, th1], [i, th1]]
			for idx in [0, 1, 2, 0, 2, 3]:
				var pi: int = corners[idx][0]
				var th: float = corners[idx][1]
				var p := pts[pi]
				var n := norms[pi]
				st.set_normal(Vector3(n.x * cos(th), n.y, n.x * sin(th)).normalized())
				st.add_vertex(Vector3(p.x * cos(th), p.y - BOWL_DROP, p.x * sin(th)))
	return st.commit()

func _build_bowl() -> void:
	var body := _mesh_instance()
	var mesh := _bowl_mesh()
	body.transform = Transform3D.IDENTITY
	body.mesh = mesh
	body.material_override = _mat(Color(0.96, 0.93, 0.85), 0.3)
	var col: CollisionShape3D = $CollisionShape3D
	col.transform = Transform3D.IDENTITY
	col.shape = mesh.create_convex_shape(true, true)
	var teal := _mat(Color(0.1, 0.5, 0.56), 0.25)
	var gold := _mat(Color(0.85, 0.66, 0.22), 0.3, 0.8)
	var tube := 0.0013
	var band_y := BOWL_H * 0.55
	_ring(_bowl_wall_radius(band_y) + tube, tube, teal, Vector3(0, band_y - BOWL_DROP, 0))
	_ring(BOWL_R - BOWL_WALL * 0.5 + tube, tube, gold, Vector3(0, BOWL_H - BOWL_DROP, 0))
	_ring(BOWL_FOOT + tube, tube, teal, Vector3(0, 0.0015 - BOWL_DROP, 0))

# --- coffee filter: creased paper with a coffee stain -----------------------

func _build_coffee_filter() -> void:
	var paper := _mat(Color(0.96, 0.93, 0.84), 0.95)
	_mesh_instance().material_override = paper
	_cyl(0.0175, 0.0175, 0.0012, _mat(Color(0.28, 0.17, 0.09), 0.9), Vector3(0, -0.0118, 0))
	_ring(0.0315, 0.0011, _mat(Color(1.0, 0.98, 0.9), 0.95), Vector3(0, 0.0145, 0))
	# Fold lines running up the cone wall
	var crease := _mat(Color(0.8, 0.74, 0.62), 0.95)
	var slope := atan2(0.0113, 0.0276)
	for i in 16:
		var pivot := Node3D.new()
		pivot.rotation.y = TAU * i / 16.0
		add_child(pivot)
		var wall_mid := Vector3(0.0254, 0.0007, 0)
		var inward := Vector3(-cos(slope), sin(slope), 0) * 0.0004
		var m := BoxMesh.new()
		m.size = Vector3(0.0007, 0.0298, 0.0008)
		_add(m, crease, wall_mid + inward, Vector3(0, 0, -rad_to_deg(slope)), pivot)

# --- erlenmeyer: empty glass flask, cork and label -------------------

func _build_erlenmeyer() -> void:
	_mesh_instance().material_override = _glass()
	_cyl(0.0105, 0.0085, 0.012, _mat(Color(0.72, 0.52, 0.3), 0.9), Vector3(0, 0.0533, 0))
	_box(Vector3(0.016, 0.012, 0.0006), _mat(Color(0.97, 0.95, 0.88), 0.8), Vector3(0, -0.003, 0.0301))
	_box(Vector3(0.012, 0.002, 0.0007), _mat(Color(0.8, 0.12, 0.1), 0.6), Vector3(0, -0.0005, 0.0302))

# --- gas: yellow gas unit with hazard stripes, valve, gauge, nozzle ----------

func _build_gas() -> void:
	_mesh_instance().material_override = _mat(Color(0.95, 0.76, 0.1), 0.45, 0.25)
	var black := _mat(Color(0.07, 0.07, 0.08), 0.6)
	var red := _mat(Color(0.8, 0.1, 0.08), 0.35)
	var steel := _mat(Color(0.75, 0.77, 0.8), 0.3, 0.8)
	# Hazard stripes along the bottom of the front face
	for i in 7:
		_box(Vector3(0.006, 0.014, 0.0006), black, Vector3(-0.036 + i * 0.012, -0.031, 0.0424), Vector3(0, 0, 40))
	# Valve on top
	_cyl(0.0075, 0.0075, 0.01, red, Vector3(0, 0.0462, 0))
	_box(Vector3(0.022, 0.003, 0.004), black, Vector3(0, 0.0522, 0))
	# Pressure gauge
	_cyl(0.0115, 0.0115, 0.002, _mat(Color(0.96, 0.96, 0.96), 0.3), Vector3(-0.02, 0.012, 0.0428), Vector3(90, 0, 0))
	_ring(0.0125, 0.0012, black, Vector3(-0.02, 0.012, 0.0432)).rotation_degrees = Vector3(90, 0, 0)
	_box(Vector3(0.0012, 0.009, 0.0006), red, Vector3(-0.0185, 0.015, 0.0436), Vector3(0, 0, -30))
	# Warning diamond
	_box(Vector3(0.017, 0.017, 0.0006), red, Vector3(0.017, 0.012, 0.0426), Vector3(0, 0, 45))
	_box(Vector3(0.0018, 0.008, 0.0007), _mat(Color(1, 1, 1), 0.6), Vector3(0.017, 0.0145, 0.043))
	_box(Vector3(0.0018, 0.0018, 0.0007), _mat(Color(1, 1, 1), 0.6), Vector3(0.017, 0.0055, 0.043))
	# Nozzle on the side
	_cyl(0.004, 0.004, 0.02, steel, Vector3(0.049, 0.0, 0), Vector3(0, 0, 90))
	_cyl(0.0058, 0.0058, 0.004, steel, Vector3(0.0412, 0.0, 0), Vector3(0, 0, 90))

# --- mixer: red hand mixer with chrome and white trim ------------------------

func _build_mixer() -> void:
	_mesh_instance().material_override = _mat(Color(0.8, 0.12, 0.1), 0.25, 0.1)
	var black := _mat(Color(0.08, 0.08, 0.09), 0.5)
	var chrome := _mat(Color(0.82, 0.84, 0.86), 0.15, 0.9)
	var white := _mat(Color(0.97, 0.97, 0.97), 0.4)
	_cyl(0.0152, 0.0152, 0.008, black, Vector3(0, 0.2038, 0))
	_ring(0.0335, 0.0015, chrome, Vector3(0, 0.1075, 0))
	_ring(0.0204, 0.0011, white, Vector3(0, 0.15, 0))
	_ring(0.0204, 0.0011, white, Vector3(0, 0.165, 0))
	# Speed knob on the side
	_cyl(0.0045, 0.0045, 0.006, black, Vector3(0.0215, 0.185, 0), Vector3(0, 0, 90))
	_box(Vector3(0.0012, 0.0035, 0.0012), white, Vector3(0.0252, 0.185, 0))

# --- petri dish: glass dish, agar with bacterial colonies, lid ---------------

func _build_petri_dish() -> void:
	_mesh_instance().material_override = _glass()
	# Lid sitting on top
	_cyl(0.0232, 0.0232, 0.0026, _mat(Color(0.8, 0.93, 1.0, 0.22), 0.05, 0.0, 2), Vector3(0, 0.0082, 0))

# --- syringe: clear empty barrel, red plunger, steel needle -----------

func _build_syringe() -> void:
	_mesh_instance().material_override = _mat(Color(0.88, 0.94, 1.0, 0.4), 0.1, 0.0, 1)
	var ink := _mat(Color(0.06, 0.06, 0.1), 0.6)
	for i in 6:
		var w := 0.006 if i % 2 == 0 else 0.0035
		_box(Vector3(w, 0.0008, 0.0008), ink, Vector3(0, -0.012 + i * 0.0068, 0.0096))
	var red := _mat(Color(0.85, 0.14, 0.14), 0.4)
	_cyl(0.0085, 0.0085, 0.005, _mat(Color(0.1, 0.1, 0.12), 0.7), Vector3(0, -0.0125, 0))
	_cyl(0.0105, 0.0105, 0.003, red, Vector3(0, -0.0372, 0))
	_cyl(0.0012, 0.0012, 0.0045, _mat(Color(0.8, 0.82, 0.85), 0.2, 0.9), Vector3(0, 0.0338, 0))
