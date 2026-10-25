extends CanvasLayer
# Heat step: the flask sits on the burner. Holding Space heats it, letting go lets it cool.
# The player has to keep the temperature in the green zone until the progress bar fills. Too
# cool and nothing happens; cross the boil line and the flask explodes, ending the run.
# The score is the share of the time spent hot that was in the green rather than above it.

signal finished(score: float)

enum State { SETUP, HEATING, EXPLODED, DONE }

const FLASK_ON_BURNER := 0.0687 # flask origin above the burner origin (rests on the tripod)
const MOVE_TIME := 0.9
const EXPLOSION_HOLD := 1.6 # seconds of fireball before the screen fades out
const CAUGHT_SCREEN = preload("res://Scripts/caught_screen.gd")

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
var green_time := 0.0
var over_time := 0.0 # above the green but under the boil line
var flask_home: Transform3D

var gauge: StepMeter
var bar: StepMeter
var status: Label
var bubbles: CPUParticles3D
var vapor: CPUParticles3D

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
	add_child(StepUtil.make_title(text))
	status = StepUtil.make_status()
	add_child(status)
	# Temperature gauge with the green zone, the red danger zone and the explosion line
	gauge = StepUtil.make_meter(900.0, 190.0)
	gauge.fill = Color(1.0, 0.45, 0.2, 0.85)
	gauge.zones = [[_frac(green_from), _frac(green_to), Color(0.3, 1.0, 0.4, 0.4)], [_frac(boil_temp), 1.0, Color(1.0, 0.2, 0.2, 0.35)]]
	gauge.marks = [[_frac(boil_temp), Color(1, 0.3, 0.3)]]
	add_child(gauge)
	bar = StepUtil.make_meter(900.0, 130.0, 28.0)
	bar.fill = Color(0.3, 1.0, 0.4, 0.9)
	add_child(bar)

func _frac(temperature: float) -> float:
	return (temperature - ambient) / (max_temp - ambient)

# Bubbles inside the liquid and vapour above the neck, parented to the flask
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
	# Once the run is over (e.g. time ran out mid-step) the flask can't go up as well
	if state != State.HEATING or Gamestate.run_over:
		return
	var held := Input.is_action_pressed("space")
	temp = clampf(temp + (heat_rate if held else -cool_rate) * delta, ambient, max_temp)
	burner.set_flame(0.15 + 0.85 * (_frac(temp) if held else _frac(temp) * 0.5))
	bubbles.emitting = temp > ambient + 25.0
	bubbles.speed_scale = 0.5 + clampf((temp - ambient - 25.0) / 70.0, 0.0, 1.0) * 2.0
	vapor.emitting = temp > green_from - 10.0
	gauge.set_value(_frac(temp))
	bar.set_value(progress)
	if temp > boil_temp:
		_explode()
	elif temp >= green_from and temp <= green_to:
		progress = minf(progress + delta / hold_seconds, 1.0)
		green_time += delta
		status.text = "Hold it in the green!    %d%%" % roundi(progress * 100.0)
		if progress >= 1.0:
			_finish()
	elif temp < green_from:
		status.text = "Hold [SPACE] to heat" if temp < green_from - 15.0 else "Almost there!"
	else:
		over_time += delta
		status.text = "Too hot - let go NOW!"

# Past the boil line the flask goes up. The run ends here: finished is never emitted
func _explode() -> void:
	state = State.EXPLODED
	Gamestate.timer_running = false
	Gamestate.run_over = true
	status.text = "BOOM"
	bubbles.emitting = false
	vapor.emitting = false
	burner.set_flame(1.0)
	var origin: Vector3 = flask.global_position + Vector3(0, 0.04, 0)
	flask.visible = false
	_spawn_explosion(origin)
	CAUGHT_SCREEN.impact_effects(get_tree(), get_viewport().get_camera_3d())
	await get_tree().create_timer(EXPLOSION_HOLD).timeout
	CAUGHT_SCREEN.end_run(get_tree(), "Your lab exploded.")

# Fireball, smoke, a growing flash sphere and a burst of light, all parented to the scene
# so they outlive the flask
func _spawn_explosion(origin: Vector3) -> void:
	var world := get_tree().current_scene
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.55, 0.1)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.45, 0.05)
	fire_mat.emission_energy_multiplier = 3.0
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fire_mesh := SphereMesh.new()
	fire_mesh.radius = 0.008
	fire_mesh.height = 0.016
	fire_mesh.material = fire_mat
	var fire := _burst(fire_mesh, 90, 1.1, origin, 0.25, 0.7, Vector3(0, -0.2, 0))
	fire.color_ramp = _fade_ramp(Color(1.0, 0.85, 0.3), Color(0.9, 0.2, 0.05, 0.0))
	fire.scale_amount_max = 2.5
	world.add_child(fire)

	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.12, 0.12, 0.12, 0.6)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.012
	smoke_mesh.height = 0.024
	smoke_mesh.material = smoke_mat
	var smoke := _burst(smoke_mesh, 40, 2.4, origin, 0.04, 0.12, Vector3(0, 0.08, 0))
	smoke.scale_amount_max = 3.5
	smoke.color_ramp = _fade_ramp(Color(0.2, 0.2, 0.2, 0.7), Color(0.05, 0.05, 0.05, 0.0))
	world.add_child(smoke)

	# A fast white-hot flash sphere
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.9, 0.6, 0.9)
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.03
	flash_mesh.height = 0.06
	flash_mesh.material = flash_mat
	var flash := MeshInstance3D.new()
	flash.mesh = flash_mesh
	flash.position = origin
	world.add_child(flash)
	var light := OmniLight3D.new()
	light.position = origin
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 8.0
	light.omni_range = 1.5
	world.add_child(light)
	var tween := create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector3.ONE * 5.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_property(light, "light_energy", 0.0, 0.9)
	tween.chain().tween_callback(flash.queue_free)
	tween.tween_callback(light.queue_free)

# A one-shot particle burst flying out from `origin`
func _burst(mesh: Mesh, amount: int, lifetime: float, origin: Vector3, speed_min: float, speed_max: float, gravity: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.position = origin
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = gravity
	p.emitting = true
	return p

func _fade_ramp(from: Color, to: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	return g

func _finish() -> void:
	state = State.DONE
	status.text = "Done!"
	bubbles.emitting = false
	vapor.emitting = false
	burner.set_flame(0.0)
	await StepUtil.move_to(flask, flask_home, MOVE_TIME).finished
	for effect in [bubbles, vapor]:
		effect.queue_free()
	finished.emit(green_time / maxf(green_time + over_time, 0.001))
