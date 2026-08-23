extends Control

const SIZE_IDLE := 4.0
const SIZE_ACTIVE := 7.0
const GAP := 3.0
const THICKNESS := 2.0
const COLOR_IDLE := Color(1, 1, 1, 0.75)
const COLOR_ACTIVE := Color(0.55, 0.85, 0.35, 0.95) # matches the HUD's green

@export var active := false:
	set(value):
		if active != value:
			active = value
			queue_redraw()

func _draw() -> void:
	var reach: float = SIZE_ACTIVE if active else SIZE_IDLE
	var color: Color = COLOR_ACTIVE if active else COLOR_IDLE
	var center := size / 2.0

	draw_line(center + Vector2(GAP, 0), center + Vector2(GAP + reach, 0), color, THICKNESS)
	draw_line(center + Vector2(-GAP, 0), center + Vector2(-GAP - reach, 0), color, THICKNESS)
	draw_line(center + Vector2(0, GAP), center + Vector2(0, GAP + reach), color, THICKNESS)
	draw_line(center + Vector2(0, -GAP), center + Vector2(0, -GAP - reach), color, THICKNESS)

	if active:
		draw_circle(center, 1.5, color)
