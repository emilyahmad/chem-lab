class_name StepMeter
extends Control
# Horizontal bar for the step UIs: a fill from 0..1, optional shaded zones and tick marks.

var value := 0.0
var fill := Color(0.95, 0.85, 0.4, 0.9)
var zones: Array = [] # [from, to, Color]
var marks: Array = [] # [position, Color]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	for zone in zones:
		draw_rect(Rect2(size.x * zone[0], 0, size.x * (zone[1] - zone[0]), size.y), zone[2])
	draw_rect(Rect2(0, 0, size.x * clampf(value, 0.0, 1.0), size.y), fill)
	for mark in marks:
		draw_line(Vector2(size.x * mark[0], -6), Vector2(size.x * mark[0], size.y + 6), mark[1], 3.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2.0)

func set_value(v: float) -> void:
	value = v
	queue_redraw()
