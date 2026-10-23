shader_type spatial;
// Chequered vinyl lab flooring, tiled in the mesh's local x/z.

uniform vec3 tile_a : source_color = vec3(0.6, 0.62, 0.63);
uniform vec3 tile_b : source_color = vec3(0.4, 0.42, 0.44);
uniform vec3 grout_color : source_color = vec3(0.12, 0.12, 0.13);
uniform float tile_size = 16.0;
uniform float grout_width = 0.03;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 t = local_pos.xz / tile_size;
	vec2 f = fract(t);
	float checker = mod(floor(t.x) + floor(t.y), 2.0);
	float grout = step(f.x, grout_width) + step(1.0 - grout_width, f.x)
			+ step(f.y, grout_width) + step(1.0 - grout_width, f.y);
	vec3 col = mix(tile_a, tile_b, checker);
	col = mix(col, grout_color, clamp(grout, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
}
