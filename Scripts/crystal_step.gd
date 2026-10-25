extends CanvasLayer
# Crystallize step: the mixture is poured into the dish and crystals grow out from the middle.
# The player presses Space to harvest. Stopping early gives a smaller batch; stopping late gives
# a more impure one. The score is the batch's purity; the yield is stored in Gamestate.

signal finished(score: float)

enum State { SETUP, GROWING, DONE }

const TILT_DEG := 55.0
const TILT_TIME := 0.8
const TIP_TIME := 1.5
const RETURN_TIME := 0.6
const IMPURITY_PENALTY := 0.7

var flask
var dish
var grow_seconds: float
var safe_until: float

var state := State.SETUP
var growth := 0.0
var dish_color: Color

var meter: StepMeter
var status: Label

# Share of crystals gone murky once growth passes the safe point
func impurity() -> float:
	return clampf((growth - safe_until) / (1.0 - safe_until), 0.0, 1.0)

func start(step: Dictionary, items: Dictionary) -> void:
	var params: Dictionary = step["params"]
	flask = items[params["flask"]]
	dish = items[params["dish"]]
	grow_seconds = params["grow_seconds"]
	safe_until = params["safe_until"]
	add_child(StepUtil.make_title(params["ui_text"]))
	status = StepUtil.make_status()
	add_child(status)
	meter = StepUtil.make_meter(900.0, 120.0)
	meter.zones = [[safe_until, 1.0, Color(1.0, 0.4, 0.2, 0.35)]]
	meter.marks = [[safe_until, UIStyle.TEXT]]
	add_child(meter)
	_run()

func _run() -> void:
	var color: Color = flask.mix_color
	dish_color = color
	var home: Transform3D = flask.global_transform
	var frac: float = flask.mix_frac
	dish.set_dish_liquid(color, 0.0)
	await StepUtil.move_to(flask, StepUtil.tilt_over(flask, dish, TILT_DEG), TILT_TIME).finished
	var tween := create_tween()
	tween.tween_method(func(a: float):
		flask.set_mix(frac * (1.0 - a), color)
		dish.set_dish_liquid(color, a), 0.0, 1.0, TIP_TIME)
	await tween.finished
	await StepUtil.move_to(flask, home, RETURN_TIME).finished
	state = State.GROWING
	status.text = "[SPACE] Harvest"

func _process(delta: float) -> void:
	if state != State.GROWING:
		return
	growth = minf(growth + delta / grow_seconds, 1.0)
	dish.set_crystals(growth, impurity())
	dish.set_dish_liquid(dish_color, 1.0 - growth)
	meter.set_value(growth)
	if growth >= 1.0:
		_finish()

func _unhandled_input(event: InputEvent) -> void:
	if state == State.GROWING and event.is_action_pressed("space"):
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	state = State.DONE
	Gamestate.batch_yield = growth
	status.text = "Harvested! Batch %d%%, purity %d%%" % [roundi(growth * 100.0), roundi((1.0 - IMPURITY_PENALTY * impurity()) * 100.0)]
	await get_tree().create_timer(1.5).timeout
	finished.emit(1.0 - IMPURITY_PENALTY * impurity())
