shader_type spatial;
// Lab bench: black epoxy-resin work surface on a painted cabinet base with
// drawers, doors, steel pulls and a dark toe-kick. Works off the mesh's local
// coordinates, so it follows the counter's scale and rotation.

uniform vec3 resin_color : source_color = vec3(0.15, 0.075, 0.075);
uniform vec3 cabinet_color : source_color = vec3(0.81, 0.76, 0.66);
uniform vec3 toe_kick_color : source_color = vec3(0.15, 0.075, 0.075);
uniform vec3 steel_color : source_color = vec3(0.64, 0.64, 0.63);
uniform float door_width = 1.2;
uniform float drawer_line = 0.55;
uniform float toe_kick_top = -0.82;

varying vec3 local_pos;
varying vec3 local_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float top = step(0.7, world_n.y);

	// Work surface: glossy black resin with a faint speckle
	float speckle = hash(floor(local_pos.xz * 140.0));
	vec3 resin = resin_color + vec3(0.03, 0.02, 0.02) * step(0.985, speckle);

	// Cabinet base
	bool facing_x = abs(local_normal.x) > abs(local_normal.z);
	float u = facing_x ? local_pos.z : local_pos.x;
	float v = local_pos.y;
	float cell = fract(u / door_width);

	float groove = step(cell, 0.012) + step(0.988, cell);
	groove += step(abs(v - drawer_line), 0.012);
	groove += step(abs(v - toe_kick_top), 0.012);
	groove = clamp(groove, 0.0, 1.0);

	// Soft shadow beside each groove, plus a slight tint per door, so the
	// fronts read as separate slabs rather than one flat coat of paint
	float to_groove = min(min(cell, 1.0 - cell) * door_width,
			min(abs(v - drawer_line), abs(v - toe_kick_top)));
	float edge_shade = 1.0 - 0.14 * smoothstep(0.07, 0.012, to_groove);
	float door_id = floor(u / door_width);
	float tint = (hash(vec2(door_id, 3.0)) - 0.5) * 0.03;

	// Pulls: a bar on each drawer, a vertical bar on each door
	float drawer_pull = step(abs(cell - 0.5), 0.16) * step(abs(v - 0.78), 0.025);
	float door_pull = step(abs(cell - 0.88), 0.012) * step(abs(v - 0.15), 0.2);
	float pull = clamp(drawer_pull + door_pull, 0.0, 1.0);

	vec3 cabinet = mix(cabinet_color + vec3(tint), toe_kick_color, step(v, toe_kick_top));
	cabinet *= edge_shade;
	cabinet = mix(cabinet, vec3(0.35, 0.28, 0.22), groove);
	cabinet = mix(cabinet, steel_color, pull);

	vec3 col = mix(cabinet, resin, top);
	ALBEDO = col;
	float is_pull = pull * (1.0 - top);
	METALLIC = is_pull * 0.35;
	ROUGHNESS = mix(mix(0.55, 0.3, is_pull), 0.18, top);
	SPECULAR = mix(0.5, 0.9, top);
}
