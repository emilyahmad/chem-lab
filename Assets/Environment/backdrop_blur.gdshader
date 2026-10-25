shader_type canvas_item;
// Slight blur of whatever is behind a modal card
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 2.0;

void fragment() {
	COLOR = textureLod(screen_tex, SCREEN_UV, blur_lod);
}
