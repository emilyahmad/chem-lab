extends CanvasLayer
# Crush step: the powder beaker tips into the bowl, the mixer is set over it, and the player
# taps Space to crush while a marker sweeps back and forth across a timing bar. Only taps with
# the marker in the green crush; the rest are misses. The step ends at 100%, or earlier with E
# once the level reaches the minimum. The score is the crush level reached times the share of
# taps that landed in the green.

signal finished(score: float)

enum State { SETUP, CRUSHING, DONE }

const TILT_DEG := 55.0
const TIP_TIME := 1.2
const TILT_TIME := 0.8
const RETURN_TIME := 0.6
const MIXER_HOVER := -0.02 # mixer's base above the bowl rim (negative: sunk into the bowl)
const MIXER_BASE := 0.103 # from the mixer's origin to its base
const BOWL_RIM := 0.0094 # from the bowl's origin
const MIXER_TAP := 0.014
const TAP_TIME := 0.06
const SWEEP_SPEED := 0.9 # back-and-forth sweeps of the timing marker per second
const SWEET_FROM := 0.35 # green part of the timing bar
const SWEET_TO := 0.65

# Beakers and bowl (ingredient_look.gd nodes), untyped to reach their fill API
var source
var bowl
var tool: Node3D
var taps_to_full: float
var min_finish: float
var color: Color

var state := State.SETUP
var level := 0.0
var taps := 0 # clean taps, in the green
var misses := 0
var sweep_time := 0.0
var source_home: Transform3D
var tool_home: Transform3D
var tool_hover: Transform3D
var tap_tween: Tween

var meter: Meter
var timing: StepMeter
var status: Label

# Horizontal meter with a notch at the minimum level for finishing early
class Meter extends Control:
	var level := 0.0
	var minimum := 0.6

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UIStyle.METER_BG)
		draw_rect(Rect2(0, 0, size.x * level, size.y), UIStyle.METER_FILL)
		draw_rect(Rect2(Vector2.ZERO, size), UIStyle.ACCENT, false, 3.0)
		var x := size.x * minimum
		draw_line(Vector2(x, -6), Vector2(x, size.y + 6), UIStyle.TEXT, 3.0)

func start(step: Dictionary, items: Dictionary) -> void:
	var params: Dictionary = step["params"]
	source = items[params["source"]]
	bowl = items[params["bowl"]]
	tool = items[params["tool"]]
	taps_to_full = params["taps_to_full"]
	min_finish = params["min_finish"]
	color = source.contents_color
	source_home = source.global_transform
	tool_home = tool.global_transform
	# Mixer hovers over the bowl's centre, base just above the rim
	var hover_pos: Vector3 = bowl.global_position
	hover_pos.y += BOWL_RIM + MIXER_HOVER - MIXER_BASE
	tool_hover = Transform3D(tool_home.basis, hover_pos)
	_build_ui(params["ui_text"])
	_run()

func _build_ui(text: String) -> void:
	add_child(StepUtil.make_title(text))
	status = StepUtil.make_status()
	add_child(status)

	meter = Meter.new()
	meter.minimum = min_finish
	meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	meter.offset_left = -450.0
	meter.offset_right = 450.0
	meter.offset_top = -164.0
	meter.offset_bottom = -120.0
	add_child(meter)

	timing = StepUtil.make_meter(900.0, 190.0, 28.0)
	timing.zones = [[SWEET_FROM, SWEET_TO, Color(0.3, 1.0, 0.4, 0.4)]]
	add_child(timing)
	_draw_marker()

# Where the timing marker is now, 0..1 across the bar
func _marker() -> float:
	return pingpong(sweep_time * SWEEP_SPEED * 2.0, 1.0)

func _draw_marker() -> void:
	timing.marks = [[_marker(), UIStyle.TEXT]]
	timing.queue_redraw()

func _process(delta: float) -> void:
	if state != State.CRUSHING:
		return
	sweep_time += delta
	_draw_marker()

func _accuracy() -> float:
	return float(taps) / maxf(taps + misses, 1.0)

# Tip the powder into the bowl, bring the mixer over, then hand over to the player
func _run() -> void:
	state = State.SETUP
	bowl.set_crush(0.0, 0.0, color)
	await StepUtil.move_to(source, StepUtil.tilt_over(source, bowl, TILT_DEG), TILT_TIME).finished
	var tip := create_tween()
	tip.tween_method(func(a: float):
		source.set_powder_amount(1.0 - a)
		bowl.set_crush(0.0, a, color), 0.0, 1.0, TIP_TIME)
	await tip.finished
	var back := StepUtil.move_to(source, source_home, RETURN_TIME)
	StepUtil.move_to(tool, tool_hover, RETURN_TIME)
	await back.finished
	state = State.CRUSHING
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if state != State.CRUSHING:
		return
	if event.is_action_pressed("space"):
		get_viewport().set_input_as_handled()
		var marker := _marker()
		if marker < SWEET_FROM or marker > SWEET_TO:
			misses += 1
			_refresh()
			return
		taps += 1
		level = minf(taps / taps_to_full, 1.0)
		bowl.set_crush(level, 1.0, color)
		_bob_tool()
		_refresh()
		if level >= 1.0:
			_finish()
	elif event.is_action_pressed("pick_up") and level >= min_finish:
		get_viewport().set_input_as_handled()
		_finish()

# Mixer dips into the bowl and comes back up on each tap
func _bob_tool() -> void:
	if tap_tween:
		tap_tween.kill()
	var down := tool_hover.origin - Vector3(0, MIXER_TAP, 0)
	tap_tween = tool.create_tween()
	tap_tween.tween_property(tool, "global_position", down, TAP_TIME)
	tap_tween.tween_property(tool, "global_position", tool_hover.origin, TAP_TIME)

func _refresh() -> void:
	meter.level = level
	meter.queue_redraw()
	var hint := "[SPACE] Crush in the green"
	if level >= min_finish:
		hint += "    [E] Done"
	status.text = "%s    %d%%    accuracy %d%%" % [hint, roundi(level * 100.0), roundi(_accuracy() * 100.0)]

func _finish() -> void:
	state = State.DONE
	status.text = "Crushed!"
	if tap_tween and tap_tween.is_running():
		await tap_tween.finished
	await StepUtil.move_to(tool, tool_home, RETURN_TIME).finished
	finished.emit(level * _accuracy())
