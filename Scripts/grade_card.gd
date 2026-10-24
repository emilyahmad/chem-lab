class_name GradeCard
extends CanvasLayer
# Shown when the last step is done: the batch's purity, size and what it will pay.
# Space closes it.

signal closed

var can_close := false

func show_result(purity: float, batch_yield: float, payout: int, step_names: Array, step_scores: Array) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(StepUtil.make_label("Batch complete", 36))
	box.add_child(StepUtil.make_label("Purity: %d%%" % roundi(purity * 100.0), 48))
	for i in step_names.size():
		var score: float = step_scores[i] if i < step_scores.size() else 0.0
		box.add_child(StepUtil.make_label("%s: %d%%" % [step_names[i], roundi(score * 100.0)], 20))
	box.add_child(StepUtil.make_label("Batch size: %d%%" % roundi(batch_yield * 100.0), 24))
	box.add_child(StepUtil.make_label("Worth $%d" % payout, 32))
	box.add_child(StepUtil.make_label("[SPACE] Continue", 20))
	# Ignore the key press that ended the last step
	await get_tree().create_timer(0.6).timeout
	can_close = true

func _unhandled_input(event: InputEvent) -> void:
	if can_close and event.is_action_pressed("space"):
		get_viewport().set_input_as_handled()
		closed.emit()
