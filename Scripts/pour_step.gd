extends CanvasLayer
# Pour step: the source beaker tips over the target and pours by itself; the player presses
# Space to stop. Landing within the tolerance of the target passes. Otherwise a countdown runs
# and the pour starts over. The score is 1.0 for an exact pour, falling off with the error.

signal finished(score: float)

enum State { TILTING, POURING, RESULT }

const TILT_DEG := 55.0
const TILT_TIME := 0.8
const RETURN_TIME := 0.6
const RETRY_SECONDS := 3
const SCORE_FALLOFF_ML := 30.0 # error at which the score hits 0
const STREAM_RADIUS := 0.0015

# Beakers (ingredient_look.gd nodes), untyped to reach their fill API
var source
var target
var target_ml: float
var tolerance_ml: float
var capacity_ml: float
var flow_ml_s: float
var source_start_ml: float
var color: Color

var state := State.TILTING
var poured := 0.0
var source_home: Transform3D
var pour_transform: Transform3D
var stream: MeshInstance3D

var gauge: Gauge
var status: Label
var readout: Label

# Vertical gauge: graduations every 10 mL, a star and shaded band at the target
class Gauge extends Control:
	var capacity := 250.0
	var target := 150.0
	var tolerance := 5.0
	var level := 0.0
	var liquid := Color.WHITE

	func _draw() -> void:
		var h := size.y
		var w := size.x
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
		var top := h - level / capacity * h
		draw_rect(Rect2(0, top, w, h - top), Color(liquid.r, liquid.g, liquid.b, 0.85))
		var band_top := h - (target + tolerance) / capacity * h
		draw_rect(Rect2(0, band_top, w, tolerance * 2.0 / capacity * h), Color(0.3, 1.0, 0.4, 0.35))
		draw_rect(Rect2(0, 0, w, h), Color.WHITE, false, 2.0)
		var font := ThemeDB.fallback_font
		for ml in range(0, int(capacity) + 1, 10):
			var y := h - ml / capacity * h
			var major := ml % 50 == 0
			draw_line(Vector2(0, y), Vector2(w * (0.5 if major else 0.28), y), Color.WHITE, 2.0 if major else 1.0)
			if major:
				draw_string(font, Vector2(w + 8, y + 5), "%d" % ml, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		var ty := h - target / capacity * h
		_draw_star(Vector2(-22, ty), 14.0)
		draw_string(font, Vector2(-170, ty + 6), "Target: %d mL" % target, HORIZONTAL_ALIGNMENT_LEFT, 140, 18, Color(1, 0.9, 0.3))

	func _draw_star(center: Vector2, radius: float) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var r := radius if i % 2 == 0 else radius * 0.42
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color(1, 0.9, 0.3))

func start(step: Dictionary, items: Dictionary) -> void:
	var params: Dictionary = step["params"]
	source = items[params["source"]]
	target = items[params["target"]]
	target_ml = params["target_ml"]
	tolerance_ml = params["tolerance_ml"]
	capacity_ml = params["capacity_ml"]
	flow_ml_s = params["flow_ml_s"]
	color = source.contents_color
	target.contents_color = color # later steps read the liquid's colour from the beaker
	source_start_ml = source.fill_ml
	source_home = source.global_transform
	pour_transform = StepUtil.tilt_over(source, target, TILT_DEG)
	_build_ui(params["ui_text"])
	_build_stream()
	_begin_pour()

func _build_ui(text: String) -> void:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 120.0
	add_child(title)

	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 26)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	status.add_theme_constant_override("outline_size", 8)
	status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_top = -150.0
	status.offset_bottom = -100.0
	add_child(status)

	gauge = Gauge.new()
	gauge.capacity = capacity_ml
	gauge.target = target_ml
	gauge.tolerance = tolerance_ml
	gauge.liquid = Color(color.r, color.g, color.b)
	gauge.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	gauge.custom_minimum_size = Vector2(64, 420)
	gauge.offset_left = -150.0
	gauge.offset_right = -86.0
	gauge.offset_top = -210.0
	gauge.offset_bottom = 210.0
	add_child(gauge)

	readout = Label.new()
	readout.add_theme_font_size_override("font_size", 28)
	readout.add_theme_color_override("font_outline_color", Color.BLACK)
	readout.add_theme_constant_override("outline_size", 8)
	readout.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	readout.offset_left = -190.0
	readout.offset_right = -50.0
	readout.offset_top = 225.0
	readout.offset_bottom = 265.0
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(readout)
	_refresh()

func _build_stream() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, maxf(color.a, 0.6))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := CylinderMesh.new()
	mesh.top_radius = STREAM_RADIUS
	mesh.bottom_radius = STREAM_RADIUS
	mesh.radial_segments = 8
	mesh.rings = 1
	stream = MeshInstance3D.new()
	stream.mesh = mesh
	stream.material_override = mat
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stream.visible = false
	add_child(stream)

# Tip the source over the target, then pour until the player stops it
func _begin_pour() -> void:
	state = State.TILTING
	poured = 0.0
	source.set_fill_ml(source_start_ml, color)
	target.set_fill_ml(0.0, color)
	status.text = ""
	_refresh()
	await StepUtil.move_to(source, pour_transform, TILT_TIME).finished
	state = State.POURING
	status.text = "Press [SPACE] to stop pouring"

func _process(delta: float) -> void:
	if state != State.POURING:
		return
	var amount := minf(flow_ml_s * delta, source.fill_ml)
	poured += amount
	source.set_fill_ml(source.fill_ml - amount, color)
	target.set_fill_ml(poured, color)
	_refresh()
	_update_stream()
	if poured >= capacity_ml or source.fill_ml <= 0.0:
		_stop_pour()

func _unhandled_input(event: InputEvent) -> void:
	if state == State.POURING and event.is_action_pressed("space"):
		get_viewport().set_input_as_handled()
		_stop_pour()

# Stream runs from the source's lip down to the liquid in the target
func _update_stream() -> void:
	var dir: Vector3 = target.global_position - source.global_position
	dir.y = 0.0
	dir = dir.normalized()
	var lip: Vector3 = source.global_position + dir * 0.036 + Vector3.UP * -0.0077
	var bottom: float = target.global_position.y + target.surface_y()
	var length := maxf(lip.y - bottom, 0.001)
	stream.global_position = Vector3(lip.x, bottom + length / 2.0, lip.z)
	(stream.mesh as CylinderMesh).height = length
	stream.visible = true

func _refresh() -> void:
	gauge.level = poured
	gauge.queue_redraw()
	readout.text = "%d mL" % roundi(poured)

func _stop_pour() -> void:
	state = State.RESULT
	stream.visible = false
	var error := poured - target_ml
	if absf(error) <= tolerance_ml:
		status.text = "Nice pour! %d mL" % roundi(poured)
		await get_tree().create_timer(1.2).timeout
		await StepUtil.move_to(source, source_home, RETURN_TIME).finished
		finished.emit(maxf(0.0, 1.0 - absf(error) / SCORE_FALLOFF_ML))
		return
	var verdict := "Too much" if error > 0.0 else "Too little"
	var back := StepUtil.move_to(source, source_home, RETURN_TIME)
	for s in range(RETRY_SECONDS, 0, -1):
		status.text = "%s (%d mL, need %d). Try again in %d..." % [verdict, roundi(poured), roundi(target_ml), s]
		await get_tree().create_timer(1.0).timeout
	await back.finished
	_begin_pour()
