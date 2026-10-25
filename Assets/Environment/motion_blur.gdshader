shader_type canvas_item;
// Directional blur along the camera's turn direction; `velocity` is in UV units per frame
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 velocity = vec2(0.0);

void fragment() {
	vec4 sum = vec4(0.0);
	for (int i = 0; i < 8; i++) {
		float t = float(i) / 7.0 - 0.5;
		sum += texture(screen_tex, SCREEN_UV + velocity * t);
	}
	COLOR = sum / 8.0;
}
