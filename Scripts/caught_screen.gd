extends CanvasLayer
# Game over: the cop has made an arrest. Same backdrop as the title screen, with the
# run's stats on a card styled like the "Batch complete" one, and a "Start over" button.

const BACKDROP := preload("res://Assets/UI/Start/MainMenu.png")
const RESTART_SCENE := "res://Scenes/Gameplay/main.tscn"

const BTN_TOP := Color("#1E7A3E") # sampled from the title screen's Start button
const BTN_BOTTOM := Color("#2B6150")

var headline := "You were caught." # set before adding to the tree
var restarting := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var backdrop := TextureRect.new()
	backdrop.texture = BACKDROP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	# Darkened so the title logo reads as a ghost behind the bad news
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	# Same card as the "Batch complete" screen
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIStyle.PANEL_BG
	style.set_corner_radius_all(12)
	style.set_content_margin_all(28.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	# Centered on the right half so the title logo in the backdrop stays visible
	panel.anchor_left = 0.75
	panel.anchor_right = 0.75
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(StepUtil.make_label(headline, UIStyle.SIZE_TITLE))
	for row in _stats():
		box.add_child(_stat_row(row[0], row[1]))
	box.add_child(_spacer(10.0))
	box.add_child(_make_button("Start over"))

func _stats() -> Array:
	var served := Gamestate.purities.size()
	var average := 0.0
	for p in Gamestate.purities:
		average += p
	average = average / maxf(served, 1.0)
	var seconds := int(Gamestate.time_survived())
	return [
		["Customers served", str(served)],
		["Average purity", "%d%%" % roundi(average * 100.0)],
		["Best batch", "%d%%" % roundi(Gamestate.best_purity * 100.0)],
		["Biggest payout", "$%d" % Gamestate.best_payout],
		["Money earned", "$%d" % Gamestate.total_earned],
		["Time on the job", "%d:%02d" % [seconds / 60, seconds % 60]],
	]

func _stat_row(label_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = 420.0
	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.style_label(name_label, UIStyle.SIZE_SMALL, UIStyle.ACCENT)
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.style_label(value_label, UIStyle.SIZE_SMALL)
	row.add_child(value_label)
	return row

func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer

# A flat green button like the title screen's Start, with no outline
func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 64)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	UIStyle.style_label(button, UIStyle.SIZE_BODY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(1.0))
	button.add_theme_stylebox_override("hover", _button_style(1.25))
	button.add_theme_stylebox_override("pressed", _button_style(0.85))
	button.pressed.connect(_on_restart)
	return button

func _button_style(brightness: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BTN_TOP.lerp(BTN_BOTTOM, 0.5) * brightness
	style.bg_color.a = 1.0
	# Clipped corners echo the title button's hexagon
	style.corner_radius_top_left = 28
	style.corner_radius_bottom_right = 28
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	return style

func _on_restart() -> void:
	if restarting:
		return
	restarting = true
	Gamestate.reset_run()
	await SceneTransition.change_scene(RESTART_SCENE)
	# This screen lives on the root, so it would otherwise survive the scene change and cover the new run
	queue_free()

# --- shared end-of-run helpers ---------------------------------------------

# Dissolves to black with the scene transition, then shows this screen with the given headline
static func end_run(tree: SceneTree, title: String) -> void:
	var transition := tree.root.get_node("SceneTransition")
	await transition.cover()
	var screen = load("res://Scripts/caught_screen.gd").new()
	screen.headline = title
	tree.root.add_child(screen)
	transition.reveal()

# A white flash and a quick camera shake for a big impact
static func impact_effects(tree: SceneTree, cam: Camera3D) -> void:
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 98
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.8)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(flash)
	tree.root.add_child(flash_layer)
	var flash_tween := tree.create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.35)
	flash_tween.tween_callback(flash_layer.queue_free)
	if cam:
		var shake := tree.create_tween()
		shake.tween_method(_shake_step.bind(cam), 0.0, 1.0, 0.5)
		shake.tween_callback(_shake_step.bind(1.0, cam))

static func _shake_step(t: float, cam: Camera3D) -> void:
	var amp := (1.0 - t) * 0.06
	cam.h_offset = randf_range(-amp, amp)
	cam.v_offset = randf_range(-amp, amp)
