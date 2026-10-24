extends CanvasLayer
# Combine step: the liquid, the crushed powder and the Catalyst Azure are tipped into the flask
# one after another, then the player holds Space to swirl. The mixture goes from clear to cloudy
# to blue as the swirl progress fills. The step ends when it is full.

signal finished(score: float)

enum State { SETUP, SWIRLING, DONE }

const TILT_DEG := 55.0
const BOWL_TILT_DEG := 70.0
const MOUTH_Y := 0.0593 # top of the flask neck, in the flask's own space
const MOUTH_CLEARANCE := 0.004
const TILT_TIME := 0.8
const TIP_TIME := 1.2
const RETURN_TIME := 0.6
const SWIRL_RADIUS := 0.006
const SWIRL_SPEED := 9.0 # rad/s
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
var flask_home: Transform3D

var meter: StepMeter
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
	_run()

# Each ingredient tips into the flask in turn
func _run() -> void:
	var clear: Color = liquid.contents_color
	var liquid_ml: float = liquid.fill_ml
	flask.set_mix(0.0, clear)
	status.text = "Removing the cork"
	await flask.pull_cork().finished
	status.text = ""
	await _tip(liquid, TILT_DEG, func(a: float):
		liquid.set_fill_ml(liquid_ml * (1.0 - a), clear)
		flask.set_mix(a * FLASK_FILL, clear))
	await _tip(powder, BOWL_TILT_DEG, func(a: float):
		powder.set_crush(powder.crush_level, 1.0 - a)
		flask.set_mix(FLASK_FILL, clear.lerp(CLOUDY, a)))
	await _tip(catalyst, TILT_DEG, func(a: float):
		catalyst.set_powder_amount(1.0 - a))
	state = State.SWIRLING
	status.text = "Hold [SPACE] to swirl"

# Tips `source` over the flask, calls `apply(0..1)` while it empties, then tips it back
func _tip(source: Node3D, tilt_deg: float, apply: Callable) -> void:
	var home := source.global_transform
	await StepUtil.move_to(source, StepUtil.tilt_over(source, flask, tilt_deg, _mouth_y() + MOUTH_CLEARANCE), TILT_TIME).finished
	var tween := create_tween()
	tween.tween_method(apply, 0.0, 1.0, TIP_TIME)
	await tween.finished
	await StepUtil.move_to(source, home, RETURN_TIME).finished

# World height of the flask's mouth; tipped items stay above it so they don't clip the neck
func _mouth_y() -> float:
	return (flask.global_transform * Vector3(0, MOUTH_Y, 0)).y

func _process(delta: float) -> void:
	if state != State.SWIRLING:
		return
	var swirling := Input.is_action_pressed("space")
	if swirling:
		progress = minf(progress + delta / swirl_seconds, 1.0)
		angle += SWIRL_SPEED * delta
	# The flask travels in a small circle while it's swirled
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * SWIRL_RADIUS * (1.0 if swirling else 0.0)
	flask.global_position = flask_home.origin + offset
	flask.set_swirl(angle * 0.6, 1.0 if swirling else 0.0)
	flask.set_mix(FLASK_FILL, CLOUDY.lerp(BLUE, progress))
	meter.set_value(progress)
	status.text = "Hold [SPACE] to swirl    %d%%" % roundi(progress * 100.0)
	if progress >= 1.0:
		_finish()

func _finish() -> void:
	state = State.DONE
	status.text = "Mixed!"
	flask.set_swirl(0.0, 0.0)
	await StepUtil.move_to(flask, flask_home, 0.3).finished
	finished.emit(1.0)
