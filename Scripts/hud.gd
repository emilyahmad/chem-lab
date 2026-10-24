extends CanvasLayer

@onready var instructions_label : RichTextLabel = %Instructions
@onready var timer_label : RichTextLabel = $Navbar/Timer

var timer_expired := false
var cooking_started := false
var intro_skipped := false
var skip_hint : Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	instructions_label.text = ""
	_place_instructions(false)
	_update_timer_label()

	skip_hint = Label.new()
	skip_hint.text = "Press [SPACE] to skip"
	skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skip_hint.offset_right = -20.0
	skip_hint.offset_bottom = -20.0
	skip_hint.modulate.a = 0.7
	add_child(skip_hint)

func _unhandled_input(event: InputEvent) -> void:
	if Gamestate.round >= 1 and Gamestate.round <= 3 and not intro_skipped and event.is_action_pressed("space"):
		intro_skipped = true
		skip_hint.visible = false
		instructions_label.text = ""
		Gamestate.round = 3

func _intro_wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds).timeout
	return not intro_skipped

func _process(delta: float) -> void:
	if Gamestate.round == 1:
		Gamestate.round = 2
		instructions_label.text = ""
		if not await _intro_wait(.6): return
		instructions_label.text = "Receive instructions the first time you cook,"
		if not await _intro_wait(2.2): return
		instructions_label.text = "Use the guides on the walls to instruct you afterwards."
		if not await _intro_wait(2.8): return
		instructions_label.text = "Make sure you don't serve police."
		if not await _intro_wait(2.5): return
		instructions_label.text = "Happy cooking!"
		if not await _intro_wait(2.0): return
		skip_hint.visible = false
		Gamestate.round = 3

	if Gamestate.round == 4:
		instructions_label.text = ""
		_place_instructions(true)
		Gamestate.round = 5
		await get_tree().create_timer(1.).timeout
		cooking_started = true

	_update_timer_label()
	if Gamestate.timer <= 0.0 and not timer_expired:
		timer_expired = true
		cooking_started = false
		instructions_label.text = "Time's up!"

	if cooking_started:
		_update_cooking_instructions()

# Intro text sits at the bottom center; once the player can move it goes top left.
# The label grows to fit its text (never scrolls), upward from the bottom or downward from the top.
func _place_instructions(top_left: bool) -> void:
	instructions_label.fit_content = true
	instructions_label.scroll_active = false
	instructions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if top_left:
		instructions_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		instructions_label.offset_left = 20.0
		instructions_label.offset_top = 100.0
		instructions_label.offset_right = 1020.0
		instructions_label.offset_bottom = 100.0
		instructions_label.grow_vertical = Control.GROW_DIRECTION_END
		instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		instructions_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		instructions_label.offset_left = 160.0
		instructions_label.offset_right = -160.0
		instructions_label.offset_top = -80.0
		instructions_label.offset_bottom = -80.0
		instructions_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _update_cooking_instructions() -> void:
	if Gamestate.order_prompt != "":
		instructions_label.text = Gamestate.order_prompt
		return
	if Gamestate.cube_picked:
		instructions_label.text = "Serve customer"
	elif Gamestate.done_mashing:
		instructions_label.text = "The mixture is ready!"
	elif Gamestate.mixer_placed:
		instructions_label.text = "Press [SPACE] to work the mixer (%d/%d)" % [Gamestate.mash_count, Gamestate.mash_target]
	elif Gamestate.bowl_placed:
		instructions_label.text = "Grab the mixer and set it on the placemat, over the bowl"
	else:
		instructions_label.text = "Grab the bowl and set it on the placemat"

func _update_timer_label() -> void:
	var seconds_left := int(ceil(Gamestate.timer))
	var minutes := int(seconds_left / 60.0)
	var seconds := seconds_left % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]
