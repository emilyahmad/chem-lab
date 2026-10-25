class_name StepUtil
# Shared moves for the step UIs.

const TILT_BACK := 0.03 # how far behind the target's centre the tilted source sits
const TILT_HEIGHT := 0.045 # and how high above it

# Where `source` ends up tipped `tilt_deg` towards `target`, its lip over the target's centre.
# Keeps the orientation the source has now, so it can be tipped back to where it started.
# With `clear_above` set (a world y), the source is raised until its lowest point is above it.
static func tilt_over(source: Node3D, target: Node3D, tilt_deg: float, clear_above := -INF) -> Transform3D:
	var to_target: Vector3 = target.global_position - source.global_position
	to_target.y = 0.0
	var dir: Vector3 = to_target.normalized()
	var tilt := Basis(Vector3.UP.cross(dir).normalized(), deg_to_rad(tilt_deg))
	var pos: Vector3 = target.global_position - dir * TILT_BACK + Vector3.UP * TILT_HEIGHT
	var result := Transform3D(tilt * source.global_transform.basis, pos)
	if clear_above > -INF:
		result.origin.y += maxf(clear_above - _lowest_y(source, result), 0.0)
	return result

# Lowest world y of `source`'s meshes if it were moved to `at`
static func _lowest_y(source: Node3D, at: Transform3D) -> float:
	var lowest := INF
	var inv := source.global_transform.affine_inverse()
	for mi: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or mi.mesh == null:
			continue
		var rel := at * inv * mi.global_transform
		var box := mi.mesh.get_aabb()
		for i in 8:
			lowest = minf(lowest, (rel * box.get_endpoint(i)).y)
	return lowest

# World point at the middle of `source`'s rim edge that sits lowest right now, i.e. where it pours from
static func lip_point(source: Node3D) -> Vector3:
	var inv := source.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or mi.mesh == null:
			continue
		var b := (inv * mi.global_transform) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var corners: Array[Vector3] = []
	for i in 8:
		var c := box.get_endpoint(i)
		if is_equal_approx(c.y, box.end.y):
			corners.append(source.global_transform * c)
	corners.sort_custom(func(a: Vector3, b: Vector3): return a.y < b.y)
	return (corners[0] + corners[1]) / 2.0

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

# Plain text for the step UIs
static func make_label(text: String, font_size := UIStyle.SIZE_BODY) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(label, font_size)
	return label

# A StepMeter centred along the bottom of the screen, `from_bottom` px up from the edge
static func make_meter(width: float, from_bottom: float, height := 44.0) -> StepMeter:
	var meter := StepMeter.new()
	meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	meter.offset_left = -width / 2.0
	meter.offset_right = width / 2.0
	meter.offset_top = -from_bottom - height
	meter.offset_bottom = -from_bottom
	return meter

# Instruction text across the top of the screen
static func make_title(text: String) -> Label:
	var title := make_label(text, UIStyle.SIZE_TITLE)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 110.0
	title.add_theme_color_override("font_color", UIStyle.ACCENT)
	return title

# Feedback line above the meters
static func make_status() -> Label:
	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(status, UIStyle.SIZE_BODY)
	status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status.grow_vertical = Control.GROW_DIRECTION_BEGIN
	status.offset_top = -280.0
	status.offset_bottom = -280.0
	return status
