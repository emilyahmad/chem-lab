extends CanvasLayer
# Heat step: the flask sits on the burner. Holding Space heats it, letting go lets it cool.
# The player has to keep the temperature in the green zone until the progress bar fills. Too
# cool and nothing happens; too hot and it foams over, which costs progress and score.

signal finished(score: float)

enum State { SETUP, HEATING, FOAMING, DONE }

const FLASK_ON_BURNER := 0.0687 # flask origin above the burner origin (rests on the tripod)
const MOVE_TIME := 0.9
const FOAM_TIME := 2.5
const FOAM_PROGRESS_LOSS := 0.5
const FOAM_RESET_TEMP := 55.0
const SCORE_PER_FOAMOVER := 0.2
const MIN_SCORE := 0.4

var flask
var burner
var ambient: float
var max_temp: float
var green_from: float
var green_to: float
var boil_temp: float
var hold_seconds: float
var heat_rate: float
var cool_rate: float

var state := State.SETUP
var temp := 20.0
var progress := 0.0
var foamovers := 0
var flask_home: Transform3D

var gauge: StepMeter
var bar: StepMeter
var status: Label
var bubbles: CPUParticles3D
var vapor: CPUParticles3D
var foam: MeshInstance3D

func start(step: Dictionary, items: Dictionary) -> void:
	var params: Dictionary = step["params"]
	flask = items[params["flask"]]
	burner = items[params["burner"]]
	ambient = params["ambient"]
	max_temp = params["max_temp"]
	green_from = params["green_from"]
	green_to = params["green_to"]
	boil_temp = params["boil_temp"]
	hold_seconds = params["hold_seconds"]
	heat_rate = params["heat_rate"]
	cool_rate = params["cool_rate"]
	temp = ambient
	flask_home = flask.global_transform
	_build_ui(params["ui_text"])
	_build_effects()
	_run()

func _build_ui(text: String) -> void:
	var title := StepUtil.make_label(text, 30)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 120.0
	add_child(title)
	status = StepUtil.make_label("", 26)
	status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_top = -230.0
	status.offset_bottom = -180.0
	add_child(status)
	# Temperature gauge with the green zone and the foam-over line
	gauge = StepUtil.make_meter(520.0, 130.0)
	gauge.fill = Color(1.0, 0.45, 0.2, 0.85)
	gauge.zones = [[_frac(green_from), _frac(green_to), Color(0.3, 1.0, 0.4, 0.4)]]
	gauge.marks = [[_frac(boil_temp), Color(1, 0.3, 0.3)]]
	add_child(gauge)
	bar = StepUtil.make_meter(520.0, 80.0, 18.0)
	bar.fill = Color(0.3, 1.0, 0.4, 0.9)
	add_child(bar)

func _frac(temperature: float) -> float:
	return (temperature - ambient) / (max_temp - ambient)

# Bubbles inside the liquid, vapour above the neck and a foam cap, all parented to the flask
func _build_effects() -> void:
	var bubble_mat := StandardMaterial3D.new()
	bubble_mat.albedo_color = Color(1, 1, 1, 0.5)
	bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 0.0015
	bubble_mesh.height = 0.003
	bubble_mesh.material = bubble_mat
	bubbles = _particles(bubble_mesh, 30, 0.9, Vector3(0, -0.01, 0), 0.018)
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 0.016
	bubbles.initial_velocity_min = 0.01
	bubbles.initial_velocity_max = 0.025
	bubbles.spread = 10.0

	var vapor_mat := StandardMaterial3D.new()
	vapor_mat.albedo_color = Color(1, 1, 1, 0.35)
	vapor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vapor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var vapor_mesh := SphereMesh.new()
	vapor_mesh.radius = 0.005
	vapor_mesh.height = 0.01
	vapor_mesh.material = vapor_mat
	vapor = _particles(vapor_mesh, 36, 2.2, Vector3(0, 0.062, 0), 0.03)
	vapor.initial_velocity_min = 0.02
	vapor.initial_velocity_max = 0.04
	vapor.spread = 14.0
	vapor.scale_amount_min = 0.6
	vapor.scale_amount_max = 2.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	vapor.color_ramp = fade

	var foam_mat := StandardMaterial3D.new()
	foam_mat.albedo_color = Color(1, 1, 1, 0.8)
	foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var foam_mesh := SphereMesh.new()
	foam_mesh.radius = 0.014
	foam_mesh.height = 0.028
	foam_mesh.material = foam_mat
	foam = MeshInstance3D.new()
	foam.mesh = foam_mesh
	foam.position = Vector3(0, 0.05, 0)
	foam.visible = false
	flask.add_child(foam)

func _particles(mesh: Mesh, amount: int, lifetime: float, pos: Vector3, _speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.position = pos
	p.direction = Vector3.UP
	p.gravity = Vector3.ZERO
	p.emitting = false
	flask.add_child(p)
	return p

func _run() -> void:
	var up := Transform3D(flask_home.basis, burner.global_position + Vector3(0, FLASK_ON_BURNER, 0))
	await StepUtil.move_to(flask, up, MOVE_TIME).finished
	burner.set_flame(0.2)
	state = State.HEATING

func _process(delta: float) -> void:
	if state != State.HEATING and state != State.FOAMING:
		return
	var held := Input.is_action_pressed("space") and state == State.HEATING
	temp = clampf(temp + (heat_rate if held else -cool_rate) * delta, ambient, max_temp)
	burner.set_flame(0.15 + 0.85 * (_frac(temp) if held else _frac(temp) * 0.5))
	bubbles.emitting = temp > ambient + 25.0
	bubbles.speed_scale = 0.5 + clampf((temp - ambient - 25.0) / 70.0, 0.0, 1.0) * 2.0
	vapor.emitting = temp > green_from - 10.0
	gauge.set_value(_frac(temp))
	bar.set_value(progress)
	if state == State.FOAMING:
		return
	if temp > boil_temp:
		_foam_over()
	elif temp >= green_from and temp <= green_to:
		progress = minf(progress + delta / hold_seconds, 1.0)
		status.text = "Hold it in the green!    %d%%" % roundi(progress * 100.0)
		if progress >= 1.0:
			_finish()
	elif temp < green_from:
		status.text = "Hold [SPACE] to heat" if temp < green_from - 15.0 else "Almost there..."
	else:
		status.text = "Getting hot - let go!"

func _foam_over() -> void:
	state = State.FOAMING
	foamovers += 1
	progress = maxf(progress - FOAM_PROGRESS_LOSS, 0.0)
	status.text = "It foamed over! Letting it settle..."
	foam.visible = true
	foam.scale = Vector3(0.3, 0.3, 0.3)
	var rise := create_tween()
	rise.tween_property(foam, "scale", Vector3(1.6, 1.8, 1.6), 0.5)
	await get_tree().create_timer(FOAM_TIME).timeout
	foam.visible = false
	temp = FOAM_RESET_TEMP
	state = State.HEATING

func _finish() -> void:
	state = State.DONE
	status.text = "Done!"
	bubbles.emitting = false
	vapor.emitting = false
	burner.set_flame(0.0)
	await StepUtil.move_to(flask, flask_home, MOVE_TIME).finished
	for effect in [bubbles, vapor, foam]:
		effect.queue_free()
	finished.emit(maxf(MIN_SCORE, 1.0 - SCORE_PER_FOAMOVER * foamovers))
