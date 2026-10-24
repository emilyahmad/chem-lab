shader_type spatial;
// Placemat: teal gingham with a cream border stripe and a dotted inner trim.
// Works off the mesh's local coordinates; node_scale compensates for the
// placemat's non-uniform scale so the checks stay square.

uniform vec3 base_color : source_color = vec3(0.96, 0.93, 0.86);
uniform vec3 check_color : source_color = vec3(0.16, 0.55, 0.60);
uniform vec3 accent_color : source_color = vec3(0.93, 0.45, 0.38);
uniform vec2 node_scale = vec2(0.0729476, 0.179592);
uniform float cell_size = 0.02;
uniform float border_width = 0.12;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float top = step(0.7, world_n.y);

	// Gingham: overlapping translucent stripes in each direction
	vec2 p = local_pos.xz * node_scale / cell_size;
	float sx = step(0.5, fract(p.x));
	float sy = step(0.5, fract(p.y));
	float weave = 0.45 * sx + 0.45 * sy; // 0, 0.45 or 0.9 coverage
	vec3 gingham = mix(base_color, check_color, weave);

	// Border: distance from the main body edge (|x|,|z| <= 1)
	vec2 edge = 1.0 - abs(local_pos.xz);
	float d = min(edge.x * node_scale.x, edge.y * node_scale.y) / min(node_scale.x, node_scale.y);
	float in_body = step(0.0, min(edge.x, edge.y));
	float border = step(d, border_width * 0.5) * in_body;

	// Dotted accent line just inside the border
	float line_d = abs(d - border_width * 0.75);
	vec2 dot_cell = fract(p * 1.0) - 0.5;
	float dots = step(line_d, 0.012) * step(length(dot_cell), 0.3) * in_body;

	vec3 col = gingham;
	col = mix(col, accent_color, border);
	col = mix(col, base_color, dots);

	// Sides and underside: solid trim color
	col = mix(accent_color * 0.8, col, top);

	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
