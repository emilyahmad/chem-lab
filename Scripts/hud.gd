extends CanvasLayer

@onready var instructions_label : RichTextLabel = %Instructions
@onready var timer_label : RichTextLabel = $Navbar/Timer

const CAUGHT_SCREEN = preload("res://Scripts/caught_screen.gd")

var timer_expired := false
var cooking_started := false
var intro_skipped := false
var skip_hint : Label
var money_label : Label
var instructions_note : PanelContainer
var instructions_blur : ColorRect
var alert_label : Label
var alert_tween : Tween
var congrats_left := CONGRATS_TIME

const ALERT_TIME := 3.5
const CONGRATS_TIME := 6.0 # seconds the note about the F-key recap shows after the first serve
const ALERT_FADE_TIME := 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	instructions_label.text = ""
	_place_instructions()
	_update_timer_label()

	money_label = Label.new()
	UIStyle.style_label(money_label, UIStyle.SIZE_TITLE, UIStyle.ACCENT)
	money_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	money_label.offset_right = -20.0
	money_label.offset_top = 8.0
	money_label.visible = false
	add_child(money_label)

	skip_hint = Label.new()
	skip_hint.text = "Press [SPACE] to skip"
	skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skip_hint.offset_right = -20.0
	skip_hint.offset_bottom = -20.0
	UIStyle.style_label(skip_hint, 20)
	skip_hint.modulate.a = 0.45
	add_child(skip_hint)
	_build_instructions_note()
	_build_alert()
	Gamestate.alert_requested.connect(_show_alert)

# Temporary notice under the navbar, top left: plain white text that fades out
func _build_alert() -> void:
	alert_label = Label.new()
	alert_label.visible = false
	alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_label.position = Vector2(20.0, 100.0)
	UIStyle.style_label(alert_label, UIStyle.SIZE_BODY, Color.WHITE)
	add_child(alert_label)

func _show_alert(text: String) -> void:
	alert_label.text = text
	alert_label.modulate.a = 1.0
	alert_label.visible = true
	if alert_tween:
		alert_tween.kill()
	alert_tween = create_tween()
	alert_tween.tween_interval(ALERT_TIME)
	alert_tween.tween_property(alert_label, "modulate:a", 0.0, ALERT_FADE_TIME)
	alert_tween.tween_callback(func(): alert_label.visible = false)

# Centered note recapping the recipe steps; F toggles it
func _build_instructions_note() -> void:
	instructions_blur = UIStyle.make_backdrop_blur()
	instructions_blur.visible = false
	add_child(instructions_blur)
	instructions_note = PanelContainer.new()
	instructions_note.visible = false
	instructions_note.set_anchors_preset(Control.PRESET_CENTER)
	instructions_note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	instructions_note.grow_vertical = Control.GROW_DIRECTION_BOTH
	instructions_note.custom_minimum_size = Vector2(1000, 0)
	# Same look as the "Batch complete" card
	var style := StyleBoxFlat.new()
	style.bg_color = UIStyle.PANEL_BG
	style.set_corner_radius_all(12)
	style.set_content_margin_all(28.0)
	instructions_note.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	instructions_note.add_child(box)
	box.add_child(StepUtil.make_label("Cooking instructions", UIStyle.SIZE_TITLE))
	for i in Recipe.STEPS.size():
		var line := StepUtil.make_label("%d. %s" % [i + 1, Recipe.STEPS[i]["instruction"]], UIStyle.SIZE_SMALL)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)
	box.add_child(StepUtil.make_label("[F] Close", UIStyle.SIZE_SMALL))
	add_child(instructions_note)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F \
			and not Gamestate.in_dialogue:
		instructions_note.visible = not instructions_note.visible
		instructions_blur.visible = instructions_note.visible
		Gamestate.instructions_open = instructions_note.visible
		get_viewport().set_input_as_handled()
		return
	if Gamestate.round >= 1 and Gamestate.round <= 3 and not intro_skipped and event.is_action_pressed("space"):
		intro_skipped = true
		skip_hint.visible = false
		instructions_label.text = ""
		Gamestate.round = 3

func _intro_wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds).timeout
	return not intro_skipped

func _process(delta: float) -> void:
	money_label.text = "$%d" % Gamestate.money
	# A dialogue starting while the recap is open would leave it stuck on screen (F is ignored in dialogue)
	if Gamestate.in_dialogue and instructions_note.visible:
		instructions_note.visible = false
		instructions_blur.visible = false
		Gamestate.instructions_open = false
	instructions_label.visible = not Gamestate.in_dialogue and get_tree().get_nodes_in_group("grade_card").is_empty()
	if Gamestate.round == 1:
		Gamestate.round = 2
		instructions_label.text = "Welcome to the van and your personal lab."
		if not await _intro_wait(3.15): return
		instructions_label.text = "You have 10 minutes"
		if not await _intro_wait(2.1): return
		instructions_label.text = "to serve as many customers as you can."
		if not await _intro_wait(3.15): return
		instructions_label.text = ""
		if not await _intro_wait(.85): return
		instructions_label.text = "Receive instructions the first time you cook,"
		if not await _intro_wait(3.1): return
		instructions_label.text = "Toggle the guide using [F] to instruct you afterwards."
		if not await _intro_wait(4.0): return
		instructions_label.text = "Don't serve police. If you spot one, shut the window on them."
		if not await _intro_wait(3.5): return
		instructions_label.text = "Happy cooking!"
		if not await _intro_wait(2.8): return
		skip_hint.visible = false
		Gamestate.round = 3

	if Gamestate.round == 4:
		instructions_label.text = ""
		_place_instructions()
		Gamestate.round = 5
		await get_tree().create_timer(1.).timeout
		cooking_started = true

	_update_timer_label()
	if Gamestate.timer <= 0.0 and not timer_expired:
		timer_expired = true
		cooking_started = false
		instructions_label.text = "Time's up!"
		_end_run_after_delay()

	if cooking_started:
		_update_cooking_instructions(delta)

# Lets "Time's up!" sink in, then the end screen with the run's stats
func _end_run_after_delay() -> void:
	Gamestate.run_over = true
	await get_tree().create_timer(1.5).timeout
	CAUGHT_SCREEN.end_run(get_tree(), "Time's up!")

# Instructions sit at the bottom center, where the interact prompt used to be (the prompt now
# sits under the crosshair). The label grows to fit its text (never scrolls), upward from the bottom.
func _place_instructions() -> void:
	instructions_label.fit_content = true
	instructions_label.scroll_active = false
	instructions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	instructions_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	instructions_label.offset_left = 160.0
	instructions_label.offset_right = -160.0
	instructions_label.offset_top = -20.0
	instructions_label.offset_bottom = -20.0
	instructions_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _update_cooking_instructions(delta: float) -> void:
	if Gamestate.order_prompt != "":
		instructions_label.text = Gamestate.order_prompt
		return
	# Once the first order is served the player knows the routine: the step instructions give
	# way to a brief note about the F-key recap
	if Gamestate.orders_served > 0:
		congrats_left -= delta
		var show_note := congrats_left > 0.0 and not Gamestate.recipe_active
		instructions_label.text = "Congrats on your first cook! Press [F] to open the instructions again" if show_note else ""
		return
	if Gamestate.cooking_prompt != "":
		instructions_label.text = Gamestate.cooking_prompt
	elif Gamestate.recipe_complete:
		instructions_label.text = "Carry the dish to the window and hand it to the customer"
	elif Gamestate.cube_picked:
		instructions_label.text = "Serve customer"
	elif Gamestate.recipe_active:
		instructions_label.text = ""
	else:
		instructions_label.text = "Explore the lab"

func _update_timer_label() -> void:
	var seconds_left := int(ceil(Gamestate.timer))
	var minutes := int(seconds_left / 60.0)
	var seconds := seconds_left % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]
