extends CanvasLayer
# Crush step: the powder beaker tips into the bowl, the mixer is set over it, and the player
# taps Space to crush. The step ends at 100%, or earlier with E once the level reaches the
# minimum. The score is the crush level reached.

signal finished(score: float)

enum State { SETUP, CRUSHING, DONE }

const TILT_DEG := 55.0
const TIP_TIME := 1.2
const TILT_TIME := 0.8
const RETURN_TIME := 0.6
const MIXER_HOVER := 0.035 # mixer's base above the bowl rim
const MIXER_BASE := 0.103 # from the mixer's origin to its base
const BOWL_RIM := 0.0094 # from the bowl's origin
const MIXER_TAP := 0.024
const TAP_TIME := 0.06

# Beakers and bowl (ingredient_look.gd nodes), untyped to reach their fill API
var source
var bowl
var tool: Node3D
var taps_to_full: float
var min_finish: float
var color: Color

var state := State.SETUP
var level := 0.0
var source_home: Transform3D
var tool_home: Transform3D
var tool_hover: Transform3D
var tap_tween: Tween

var meter: Meter
var status: Label

# Horizontal meter with a notch at the minimum level for finishing early
class Meter extends Control:
	var level := 0.0
	var minimum := 0.6

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(0, 0, size.x * level, size.y), Color(0.95, 0.85, 0.4, 0.9))
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2.0)
		var x := size.x * minimum
		draw_line(Vector2(x, -6), Vector2(x, size.y + 6), Color.WHITE, 3.0)

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
	var title := _label(text, 30)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 120.0
	add_child(title)

	status = _label("", 26)
	status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_top = -190.0
	status.offset_bottom = -140.0
	add_child(status)

	meter = Meter.new()
	meter.minimum = min_finish
	meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	meter.offset_left = -220.0
	meter.offset_right = 220.0
	meter.offset_top = -120.0
	meter.offset_bottom = -90.0
	add_child(meter)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	return label

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
		level = minf(level + 1.0 / taps_to_full, 1.0)
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
	var hint := "[SPACE] Crush"
	if level >= min_finish:
		hint += "    [E] Done"
	status.text = "%s    %d%%" % [hint, roundi(level * 100.0)]

func _finish() -> void:
	state = State.DONE
	status.text = "Crushed!"
	if tap_tween and tap_tween.is_running():
		await tap_tween.finished
	await StepUtil.move_to(tool, tool_home, RETURN_TIME).finished
	finished.emit(level)
