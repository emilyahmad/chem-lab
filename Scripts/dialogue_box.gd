extends CanvasLayer

signal finished
signal choice_made(id: String)

@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var choices_box: VBoxContainer = %Choices
@onready var hint_label: Label = %Hint

const SELECTED_COLOR := UIStyle.ACCENT
const NORMAL_COLOR := UIStyle.TEXT
# Seconds after a dialogue ends before Space can jump again
const JUMP_REENABLE_DELAY := 0.3

var lines: Array = []
var index := 0
var active := false

var choices: Array = []
var selected := 0

func _ready() -> void:
	$Panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	visible = false

# Each line is {"speaker": String, "text": String}. A line can also carry
# "choices": [{"text": String, "id": String (optional), "reply": Array of lines (optional)}].
# When the player picks one, their text is spoken as a Player line, then the reply lines
# play, then the dialogue carries on with whatever follows the choice line.
func start(new_lines: Array) -> void:
	lines = new_lines.duplicate()
	index = 0
	active = true
	Gamestate.in_dialogue = true
	visible = true
	_set_jump_blocked(true)
	_show_line()

# Space continues the dialogue and the arrow keys pick choices, so keep the player
# from jumping or using the arrow keys to walk while it's open
func _set_jump_blocked(blocked: bool) -> void:
	if not blocked:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.move_blocked = false
		# Keep jump disabled briefly so the Space press that ended the dialogue doesn't also jump
		await get_tree().create_timer(JUMP_REENABLE_DELAY).timeout
		# A new dialogue may have opened during the wait
		if active:
			return
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.jump_blocked = blocked
		player.move_blocked = blocked

func _show_line() -> void:
	var line: Dictionary = lines[index]
	speaker_label.text = line["speaker"]
	text_label.text = line["text"]
	_clear_choices()
	choices = line.get("choices", [])
	selected = 0
	if choices.is_empty():
		hint_label.text = "[Space] Continue"
	else:
		hint_label.text = ""
		for choice in choices:
			var label := Label.new()
			label.add_theme_font_size_override("font_size", UIStyle.SIZE_SMALL)
			choices_box.add_child(label)
		_refresh_choices()

func _clear_choices() -> void:
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()

func _refresh_choices() -> void:
	for i in choices.size():
		var label: Label = choices_box.get_child(i)
		label.text = "%s %d. %s" % [">" if i == selected else " ", i + 1, choices[i]["text"]]
		label.add_theme_color_override("font_color", SELECTED_COLOR if i == selected else NORMAL_COLOR)

func _choose(i: int) -> void:
	var choice: Dictionary = choices[i]
	var inserted: Array = [{"speaker": "Player", "text": choice["text"]}]
	inserted.append_array(choice.get("reply", []))
	_insert_after(index, inserted)
	if choice.has("id"):
		choice_made.emit(choice["id"])
	_advance()

func _insert_after(at: int, new_lines: Array) -> void:
	for i in new_lines.size():
		lines.insert(at + 1 + i, new_lines[i])

func _advance() -> void:
	index += 1
	if index >= lines.size():
		active = false
		Gamestate.in_dialogue = false
		visible = false
		_set_jump_blocked(false)
		finished.emit()
	else:
		_show_line()

func _is_arrow_press(event: InputEvent, key: Key) -> bool:
	return event is InputEventKey and event.pressed and event.physical_keycode == key

# Space (the jump action) or either Enter key
func _is_confirm_press(event: InputEvent) -> bool:
	return event.is_action_pressed("jump") or (event is InputEventKey and event.pressed and not event.echo \
		and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER))

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if not choices.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			var number: int = event.keycode - KEY_1
			if number >= 0 and number < choices.size():
				get_viewport().set_input_as_handled()
				_choose(number)
				return
		# Arrow keys only; WASD is reserved for movement
		if _is_arrow_press(event, KEY_UP):
			selected = (selected - 1 + choices.size()) % choices.size()
			_refresh_choices()
			get_viewport().set_input_as_handled()
		elif _is_arrow_press(event, KEY_DOWN):
			selected = (selected + 1) % choices.size()
			_refresh_choices()
			get_viewport().set_input_as_handled()
		elif _is_confirm_press(event):
			get_viewport().set_input_as_handled()
			_choose(selected)
		return

	if _is_confirm_press(event):
		get_viewport().set_input_as_handled()
		_advance()
