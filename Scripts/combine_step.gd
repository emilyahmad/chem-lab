extends CanvasLayer
# Combine step: the liquid, the crushed powder and the Catalyst Azure are tipped into the flask
# one after another, then the player swirls: holding Space speeds the swirl up, letting go slows
# it down. Swirling fast enough fills the progress and turns the mixture from cloudy to blue;
# too fast and it spills. The step ends when the progress is full. The score is the share of
# that swirling done in the green band rather than spilling.

signal finished(score: float)

enum State { SETUP, SWIRLING, DONE }

const TILT_DEG := 55.0
const BOWL_TILT_DEG := 70.0
const MOUTH_Y := 0.0593 # top of the flask neck, in the flask's own space
const MOUTH_CLEARANCE := 0.004
const TILT_TIME := 0.8
const TIP_TIME := 1.2
const RETURN_TIME := 0.6
const LIFT_TIME := 0.4
const BOWL_LIFT := 0.03 # extra height for the bowl and catalyst so they clear what is on the placemat
const CATALYST_LIFT := 0.025
const STREAM_GRAVITY := 3.0 # m/s^2, gentler than real so the fall reads on screen
const SWIRL_RADIUS := 0.006
const SWIRL_SPEED := 9.0 # rad/s at the top of the green band
const SWIRL_ACCEL := 0.8 # swirl speed (0..1) gained per second while Space is held
const SWIRL_DECAY := 0.6 # and lost per second once it's let go
const BAND_FROM := 0.45 # green band of the swirl speed; above it the mixture spills
const BAND_TO := 0.75
const FLASK_FILL := 0.55
const CLOUDY := Color(0.92, 0.93, 0.95, 0.6)
const BLUE := Color(0.15, 0.4, 0.95, 0.85)

# Items are ingredient_look.gd nodes, untyped to reach their fill API
var flask
var liquid
var powder
var catalyst
var swirl_seconds: float

var state := State.SETUP
var progress := 0.0
var angle := 0.0
var speed := 0.0 # 0..1
var band_time := 0.0
var spill_time := 0.0
var flask_home: Transform3D

var meter: StepMeter
var gauge: StepMeter
var status: Label

func start(step: Dictionary, items: Dictionary) -> void:
	var params: Dictionary = step["params"]
	flask = items[params["flask"]]
	liquid = items[params["liquid"]]
	powder = items[params["powder"]]
	catalyst = items[params["catalyst"]]
	swirl_seconds = params["swirl_seconds"]
	flask_home = flask.global_transform
	add_child(StepUtil.make_title(params["ui_text"]))
	status = StepUtil.make_status()
	add_child(status)
	meter = StepUtil.make_meter(900.0, 120.0)
	add_child(meter)
	# Swirl speed, with the green band and the red spill zone above it
	gauge = StepUtil.make_meter(900.0, 190.0)
	gauge.fill = Color(0.35, 0.6, 1.0, 0.85)
	gauge.zones = [[BAND_FROM, BAND_TO, Color(0.3, 1.0, 0.4, 0.4)], [BAND_TO, 1.0, Color(1.0, 0.2, 0.2, 0.35)]]
	add_child(gauge)
	_run()

# Each ingredient tips into the flask in turn
func _run() -> void:
	var clear: Color = liquid.contents_color
	var liquid_ml: float = liquid.fill_ml
	flask.set_mix(0.0, clear)
	status.text = "Removing the cork"
	await flask.pull_cork().finished
	status.text = ""
	await _tip(liquid, TILT_DEG, 0.0, clear.lerp(Color(0.7, 0.85, 1.0), 0.5), func(a: float):
		liquid.set_fill_ml(liquid_ml * (1.0 - a), clear)
		flask.set_mix(a * FLASK_FILL, clear))
	await _tip(powder, BOWL_TILT_DEG, BOWL_LIFT, Color(0.93, 0.92, 0.88), func(a: float):
		powder.set_crush(powder.crush_level, 1.0 - a)
		flask.set_mix(FLASK_FILL, clear.lerp(CLOUDY, a)))
	await _tip(catalyst, TILT_DEG, CATALYST_LIFT, Color(0.2, 0.5, 1.0), func(a: float):
		catalyst.set_powder_amount(1.0 - a))
	state = State.SWIRLING
	status.text = "Hold [SPACE] to swirl faster"

# Lifts `source` straight up by `lift`, tips it over the flask, calls `apply(0..1)` while it empties
# with a stream falling into the flask, then tips it back and sets it down
func _tip(source: Node3D, tilt_deg: float, lift: float, stream_color: Color, apply: Callable) -> void:
	var home := source.global_transform
	var up := Vector3.UP * lift
	if lift > 0.0:
		await StepUtil.move_to(source, Transform3D(home.basis, home.origin + up), LIFT_TIME).finished
	var over := StepUtil.tilt_over(source, flask, tilt_deg, _mouth_y() + MOUTH_CLEARANCE)
	over.origin += up
	await StepUtil.move_to(source, over, TILT_TIME).finished
	var stream := _make_stream(stream_color, StepUtil.lip_point(source))
	stream.emitting = true
	var tween := create_tween()
	tween.tween_method(apply, 0.0, 1.0, TIP_TIME)
	await tween.finished
	stream.emitting = false
	get_tree().create_timer(stream.lifetime).timeout.connect(stream.queue_free)
	if lift > 0.0:
		await StepUtil.move_to(source, Transform3D(home.basis, home.origin + up), TILT_TIME).finished
		await StepUtil.move_to(source, home, LIFT_TIME).finished
	else:
		await StepUtil.move_to(source, home, RETURN_TIME).finished

# Droplets leaving the pouring container's lip: they spill out sideways toward the flask, then
# arc down under gravity and are gone by the time they reach the flask's mouth
func _make_stream(color: Color, lip: Vector3) -> CPUParticles3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := SphereMesh.new()
	mesh.radius = 0.0012
	mesh.height = 0.0024
	mesh.material = mat
	var mouth: Vector3 = flask.global_transform * Vector3(0, MOUTH_Y, 0)
	var toward: Vector3 = mouth - lip
	toward.y = 0.0
	toward = toward.normalized()
	var fall := maxf(lip.y - mouth.y, 0.005)
	var speed := 0.03
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.amount = 60
	p.lifetime = sqrt(2.0 * fall / STREAM_GRAVITY) + 0.02
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.0015
	p.direction = toward + Vector3.DOWN * 0.2
	p.spread = 5.0
	p.initial_velocity_min = speed * 0.8
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -STREAM_GRAVITY, 0)
	p.emitting = false
	flask.add_child(p)
	p.global_position = lip
	return p

# World height of the flask's mouth; tipped items stay above it so they don't clip the neck
func _mouth_y() -> float:
	return (flask.global_transform * Vector3(0, MOUTH_Y, 0)).y

func _process(delta: float) -> void:
	if state != State.SWIRLING:
		return
	var held := Input.is_action_pressed("space")
	speed = clampf(speed + (SWIRL_ACCEL if held else -SWIRL_DECAY) * delta, 0.0, 1.0)
	angle += SWIRL_SPEED * speed / BAND_TO * delta
	var hint: String
	if speed < BAND_FROM:
		hint = "Hold [SPACE] to swirl faster"
	else:
		progress = minf(progress + delta / swirl_seconds, 1.0)
		if speed <= BAND_TO:
			band_time += delta
			hint = "Keep it steady!"
		else:
			spill_time += delta
			hint = "Too fast - it's spilling!"
	# The flask travels in a small circle while it's swirled, wider the faster it goes
	var amount := clampf(speed / BAND_FROM, 0.0, 1.0)
	var swirl_offset := Vector3(cos(angle), 0.0, sin(angle)) * SWIRL_RADIUS * clampf(speed / BAND_FROM, 0.0, 1.5)
	flask.global_position = flask_home.origin + swirl_offset
	flask.set_swirl(angle * 0.6, amount)
	flask.set_mix(FLASK_FILL, CLOUDY.lerp(BLUE, progress))
	meter.set_value(progress)
	gauge.set_value(speed)
	status.text = "%s    %d%%" % [hint, roundi(progress * 100.0)]
	if progress >= 1.0:
		_finish()

func _finish() -> void:
	state = State.DONE
	status.text = "Mixed!"
	flask.set_swirl(0.0, 0.0)
	await StepUtil.move_to(flask, flask_home, 0.3).finished
	finished.emit(band_time / maxf(band_time + spill_time, 0.001))
