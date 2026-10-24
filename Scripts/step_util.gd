class_name StepUtil
# Shared moves for the step UIs.

const TILT_BACK := 0.03 # how far behind the target's centre the tilted source sits
const TILT_HEIGHT := 0.045 # and how high above it

# Where `source` ends up tipped `tilt_deg` towards `target`, its lip over the target's centre.
# Keeps the orientation the source has now, so it can be tipped back to where it started.
static func tilt_over(source: Node3D, target: Node3D, tilt_deg: float) -> Transform3D:
	var to_target: Vector3 = target.global_position - source.global_position
	to_target.y = 0.0
	var dir: Vector3 = to_target.normalized()
	var tilt := Basis(Vector3.UP.cross(dir).normalized(), deg_to_rad(tilt_deg))
	var pos: Vector3 = target.global_position - dir * TILT_BACK + Vector3.UP * TILT_HEIGHT
	return Transform3D(tilt * source.global_transform.basis, pos)

# Tweens `node` from where it is now to `to`. Await the returned tween's `finished`.
static func move_to(node: Node3D, to: Transform3D, seconds: float) -> Tween:
	var from := node.global_transform
	var tween := node.create_tween()
	tween.tween_method(func(t: float):
		node.global_transform = Transform3D(
				from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), t),
				from.origin.lerp(to.origin, t)), 0.0, 1.0, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

# Outlined white text for the step UIs
static func make_label(text: String, font_size := 26) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	return label

# A StepMeter centred along the bottom of the screen, `from_bottom` px up from the edge
static func make_meter(width: float, from_bottom: float, height := 28.0) -> StepMeter:
	var meter := StepMeter.new()
	meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	meter.offset_left = -width / 2.0
	meter.offset_right = width / 2.0
	meter.offset_top = -from_bottom - height
	meter.offset_bottom = -from_bottom
	return meter
