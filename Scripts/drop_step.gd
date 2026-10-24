extends CanvasLayer
# Drop step: the syringe draws up Quench solution and holds over the flask. Each Space press
# adds one drop and the mixture shifts colour. The player compares it with the target shade
# and presses E when it matches. The score depends on how close the drop count is to the one
# that gives the target shade.

signal finished(score: float)

enum State { SETUP, DROPPING, DONE }

const MOVE_TIME := 0.8
const DRAW_TIME := 0.8
const DROP_FALL_TIME := 0.18
const DROP_COOLDOWN := 0.3
const SCORE_FALLOFF_DROPS := 6.0
const SYRINGE_TIP := 0.036 # from the syringe's origin to its needle tip
const FLASK_MOUTH := 0.075 # above the flask's origin
const DROP_ML := 1.0
const DRAW_ML := 5.0
const MIX_FRAC := 0.55

# The mixture's colour after n drops, interpolated between these stops [drops, colour]
const STOPS := [
	[0.0, Color(0.15, 0.4, 0.95, 0.85)],
	[6.0, Color(0.1, 0.7, 0.8, 0.85)],
	[12.0, Color(0.2, 0.85, 0.45, 0.85)],
	[18.0, Color(0.9, 0.85, 0.2, 0.85)],
	[24.0, Color(0.95, 0.5, 0.15, 0.85)],
]

var flask
var syringe
var quench
var max_drops: int
var target_drops: int

var state := State.SETUP
var drops := 0
var cooldown := 0.0
var syringe_home: Transform3D
var over_flask: Transform3D
var drop_mesh: MeshInstance3D

var current_swatch: ColorRect
var count_label: Label
var status: Label

static func shade(n: float) -> Color:
	for i in range(1, STOPS.size()):
		if n <= STOPS[i][0]:
			return (STOPS[i - 1][1] as Color).lerp(STOPS[i][1], (n - STOPS[i - 1][0]) / (STOPS[i][0] - STOPS[i - 1][0]))
	return STOPS[STOPS.size() - 1][1]

func start(step: Dictionary, items: Dictionary) -> void:
	var params: Dictionary = step["params"]
	flask = items[params["flask"]]
	syringe = items[params["syringe"]]
	quench = items[params["quench"]]
	max_drops = params["max_drops"]
	target_drops = randi_range(params["drops_min"], params["drops_max"])
	syringe_home = syringe.global_transform
	# Needle down, tip just above the flask's mouth
	var upright := Basis(Vector3.RIGHT, PI)
	over_flask = Transform3D(upright, flask.global_position + Vector3(0, FLASK_MOUTH + SYRINGE_TIP, 0))
	_build_ui(params["ui_text"])
	_build_drop()
	flask.set_mix(MIX_FRAC, shade(0))
	_run()

func _build_ui(text: String) -> void:
	add_child(StepUtil.make_title(text))
	status = StepUtil.make_status()
	add_child(status)
	# Target shade and the mixture's current shade side by side
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -300.0
	row.offset_right = 300.0
	row.offset_top = -230.0
	row.offset_bottom = -60.0
	row.add_theme_constant_override("separation", 60)
	add_child(row)
	_swatch("Target shade", shade(target_drops), row)
	current_swatch = _swatch("Current", shade(0), row)
	count_label = StepUtil.make_label("Drops: 0", UIStyle.SIZE_BODY)
	count_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	count_label.offset_left = -360.0
	count_label.offset_right = -60.0
	add_child(count_label)

# A colour block with a caption under it; returns the block
func _swatch(caption: String, color: Color, parent: Node = null) -> ColorRect:
	var box := VBoxContainer.new()
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(270, 90)
	rect.color = Color(color.r, color.g, color.b)
	box.add_child(rect)
	var label := StepUtil.make_label(caption, UIStyle.SIZE_SMALL)
	box.add_child(label)
	if parent:
		parent.add_child(box)
	return rect

func _build_drop() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = quench.contents_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := SphereMesh.new()
	mesh.radius = 0.0022
	mesh.height = 0.0044
	mesh.material = mat
	drop_mesh = MeshInstance3D.new()
	drop_mesh.mesh = mesh
	drop_mesh.visible = false
	flask.add_child(drop_mesh)

# Dip into the Quench beaker, draw up, then hold over the flask
func _run() -> void:
	var dip := Transform3D(over_flask.basis, quench.global_position + Vector3(0, quench.surface_y() + SYRINGE_TIP + 0.004, 0))
	await StepUtil.move_to(syringe, dip, MOVE_TIME).finished
	var ml: float = quench.fill_ml
	var tween := create_tween()
	tween.tween_method(func(a: float): quench.set_fill_ml(ml - DRAW_ML * a, quench.contents_color), 0.0, 1.0, DRAW_TIME)
	await tween.finished
	await StepUtil.move_to(syringe, over_flask, MOVE_TIME).finished
	state = State.DROPPING
	status.text = "[SPACE] Add a drop    [E] Done"

func _process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if state != State.DROPPING:
		return
	if event.is_action_pressed("space") and cooldown <= 0.0:
		get_viewport().set_input_as_handled()
		cooldown = DROP_COOLDOWN
		_add_drop()
	elif event.is_action_pressed("pick_up") and drops > 0:
		get_viewport().set_input_as_handled()
		_finish()

func _add_drop() -> void:
	drops += 1
	count_label.text = "Drops: %d" % drops
	# The drop falls from the needle tip to the liquid's surface, then the colour changes
	var tip_y: float = syringe.global_position.y - SYRINGE_TIP - flask.global_position.y
	var surface_y: float = flask.FLASK_FLOOR_Y + flask.mix_frac * flask.FLASK_FILL_H
	drop_mesh.position = Vector3(0, tip_y, 0)
	drop_mesh.visible = true
	var fall := create_tween()
	fall.tween_property(drop_mesh, "position:y", surface_y, DROP_FALL_TIME).set_ease(Tween.EASE_IN)
	await fall.finished
	drop_mesh.visible = false
	var color := shade(drops)
	flask.set_mix(MIX_FRAC, color)
	current_swatch.color = Color(color.r, color.g, color.b)
	quench.set_fill_ml(quench.fill_ml - DROP_ML, quench.contents_color)
	if drops >= max_drops and state == State.DROPPING:
		_finish()

func _finish() -> void:
	if state == State.DONE:
		return
	state = State.DONE
	status.text = "Done!"
	await StepUtil.move_to(syringe, syringe_home, MOVE_TIME).finished
	drop_mesh.queue_free()
	finished.emit(maxf(0.0, 1.0 - absf(drops - target_drops) / SCORE_FALLOFF_DROPS))
