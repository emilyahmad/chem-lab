extends CanvasLayer
# Placeholder step UI so the step runner can be tested before the real step UIs exist.
# Space completes the step with a perfect score.

signal finished(score: float)

func start(step: Dictionary, _items: Dictionary) -> void:
	var label := Label.new()
	label.text = "[%s step]\nPress [SPACE] to finish" % step["type"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(label, UIStyle.SIZE_BODY)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("space"):
		get_viewport().set_input_as_handled()
		finished.emit(1.0)
