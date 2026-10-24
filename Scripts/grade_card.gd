class_name GradeCard
extends CanvasLayer
# Shown when the last step is done: the batch's purity, size and what it will pay.
# Space closes it.

signal closed

var can_close := false

func show_result(purity: float, batch_yield: float, payout: int, cook_time: float, speed_bonus: float, step_names: Array, step_scores: Array) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(StepUtil.make_label("Batch complete", UIStyle.SIZE_TITLE))
	box.add_child(StepUtil.make_label("Purity: %d%%" % roundi(purity * 100.0), UIStyle.SIZE_TITLE))
	for i in step_names.size():
		var score: float = step_scores[i] if i < step_scores.size() else 0.0
		box.add_child(StepUtil.make_label("%s: %d%%" % [step_names[i], roundi(score * 100.0)], UIStyle.SIZE_SMALL))
	box.add_child(StepUtil.make_label("Batch size: %d%%" % roundi(batch_yield * 100.0), UIStyle.SIZE_BODY))
	box.add_child(StepUtil.make_label("Time: %d:%02d (speed bonus +%d%%)" % [int(cook_time) / 60, int(cook_time) % 60, roundi(speed_bonus * 100.0)], UIStyle.SIZE_BODY))
	box.add_child(StepUtil.make_label("Worth $%d" % payout, UIStyle.SIZE_BODY))
	box.add_child(StepUtil.make_label("[SPACE] Continue", UIStyle.SIZE_SMALL))
	# Ignore the key press that ended the last step
	await get_tree().create_timer(0.6).timeout
	can_close = true

func _unhandled_input(event: InputEvent) -> void:
	if can_close and event.is_action_pressed("space"):
		get_viewport().set_input_as_handled()
		closed.emit()
