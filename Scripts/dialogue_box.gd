extends CanvasLayer

signal finished
signal choice_made(id: String)

@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var choices_box: VBoxContainer = %Choices
@onready var hint_label: Label = %Hint

const SELECTED_COLOR := Color(1, 0.85, 0.4)
const NORMAL_COLOR := Color(1, 1, 1)

var lines: Array = []
var index := 0
var active := false

var choices: Array = []
var selected := 0

func _ready() -> void:
	visible = false

# Each line is {"speaker": String, "text": String}. A line can also carry
# "choices": [{"text": String, "id": String (optional), "reply": Array of lines (optional)}].
# When the player picks one, their text is spoken as a Player line, then the reply lines
# play, then the dialogue carries on with whatever follows the choice line.
func start(new_lines: Array) -> void:
	lines = new_lines.duplicate()
	index = 0
	active = true
	visible = true
	_set_jump_blocked(true)
	_show_line()

# Space continues the dialogue, so keep the player from jumping while it's open
func _set_jump_blocked(blocked: bool) -> void:
	if not blocked:
		# Wait a physics frame so the Space press that ended the dialogue doesn't also jump
		await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.jump_blocked = blocked

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
		hint_label.text = "[W/S] Select    [Space] or [1-%d] Choose" % choices.size()
		for choice in choices:
			var label := Label.new()
			label.add_theme_font_size_override("font_size", 20)
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
		visible = false
		_set_jump_blocked(false)
		finished.emit()
	else:
		_show_line()

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
		if event.is_action_pressed("up"):
			selected = (selected - 1 + choices.size()) % choices.size()
			_refresh_choices()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("down"):
			selected = (selected + 1) % choices.size()
			_refresh_choices()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("jump"):
			get_viewport().set_input_as_handled()
			_choose(selected)
		return

	if event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		_advance()
