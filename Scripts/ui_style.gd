class_name UIStyle
# One look for every on-screen UI: font, sizes and a green palette. No text outlines.

const FONT := preload("res://Assets/UI/Fonts/Cooper Lt BT W08 Regular.ttf")

const SIZE_TITLE := 48
const SIZE_BODY := 36
const SIZE_SMALL := 28

const GREEN := Color("#004A19")
const GREEN_DARK := Color("#00250D") # GREEN darkened 50%
const GREEN_TOP := Color("#336E47") # GREEN lightened 20%
const GREEN_LIGHT := Color("#2FA45A") # lighter tint of GREEN for borders and fills

const TEXT := Color("#E6F5EA")
const ACCENT := Color("#8FD9A8")
const STAR := Color("#FFD84A")

const PANEL_BG := Color(GREEN_DARK, 0.92)
const PANEL_BORDER := GREEN_LIGHT
const METER_BG := Color(GREEN_DARK, 0.85)
const METER_FILL := Color(GREEN_LIGHT, 0.95)

const BACKDROP_BLUR := preload("res://Assets/Environment/backdrop_blur.gdshader")

const TEX_SIZE := 96
const BORDER := 5

static var _panel_texture: ImageTexture

# Vertical GREEN_TOP -> GREEN_DARK gradient with a light border
static func panel_texture() -> ImageTexture:
	if _panel_texture:
		return _panel_texture
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	for y in TEX_SIZE:
		var base := GREEN_TOP.lerp(GREEN_DARK, float(y) / (TEX_SIZE - 1))
		for x in TEX_SIZE:
			var c := base
			var edge := mini(mini(x, TEX_SIZE - 1 - x), mini(y, TEX_SIZE - 1 - y))
			if edge < BORDER:
				c = GREEN_LIGHT.lerp(GREEN, float(edge) / BORDER)
			img.set_pixel(x, y, Color(c, 0.94))
	_panel_texture = ImageTexture.create_from_image(img)
	return _panel_texture

static func panel_style(margin := 28.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = panel_texture()
	style.set_texture_margin_all(BORDER)
	style.set_content_margin_all(margin)
	return style

# Applies the shared font and colour to a label with a soft drop shadow (no outline).
# `boxed` puts it on the green panel instead, for dialogue-style text
static func style_label(label: Control, font_size := SIZE_BODY, color := TEXT, boxed := false) -> void:
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if not boxed:
		label.add_theme_color_override("font_shadow_color", Color(GREEN_DARK, 0.85))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
	if boxed and label is Label:
		var style := panel_style(14.0)
		style.content_margin_left = 24.0
		style.content_margin_right = 24.0
		label.add_theme_stylebox_override("normal", style)

# Full-screen rect that softly blurs everything drawn before it; add it under a modal card
static func make_backdrop_blur() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = ShaderMaterial.new()
	rect.material.shader = BACKDROP_BLUR
	return rect
