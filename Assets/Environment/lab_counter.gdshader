shader_type spatial;
// Lab bench: black epoxy-resin work surface on a painted cabinet base with
// wide drawers over pairs of doors, brushed-steel bar pulls and a recessed toe-kick.
//
// Doors are laid out per cabinet face (see FACES) so they fit between the
// corners instead of tiling from an arbitrary origin, and all sizes are in
// world units (the counter node is scaled non-uniformly), so doors, gaps
// and pulls keep the same proportions on every side.

uniform vec3 resin_color : source_color = vec3(0.15, 0.075, 0.075);
uniform vec3 cabinet_color : source_color = vec3(0.81, 0.76, 0.66);
uniform vec3 toe_kick_color : source_color = vec3(0.15, 0.075, 0.075);
uniform vec3 steel_color : source_color = vec3(0.78, 0.78, 0.77);
// Target door width; the actual width is fitted so each face holds a whole
// number of doors.
uniform float door_width = 0.2;
// Frame strip left at each end of a face (covers inside corners)
uniform float stile = 0.012;
uniform float gap = 0.0025;
// Heights in the mesh's local Y (cabinet runs from -1 to 1)
uniform float drawer_line = 0.55;
uniform float toe_kick_top = -0.82;
// Bar pulls (world units)
uniform float pull_radius = 0.0024;
uniform float door_pull_length = 0.05;
uniform float pull_inset = 0.016;

varying vec3 local_pos;
varying vec3 local_normal;

// Cabinet faces of the counter mesh, in local coordinates:
// (facing axis: 0 = X so the face runs along Z, 1 = Z so it runs along X;
//  plane coordinate; run start; run end)
const int FACE_COUNT = 8;
const vec4 FACES[FACE_COUNT] = vec4[](
	vec4(0.0, -0.185357, -6.22022, -1.0),      // main run front
	vec4(0.0, 1.0, -1.0, 1.0),                 // bump-out front
	vec4(0.0, 0.944124, -7.99628, -6.22022),   // far bump-out front
	vec4(0.0, -2.27414, -7.99628, 1.0),        // back
	vec4(1.0, -1.0, -0.185357, 1.0),           // bump-out side
	vec4(1.0, -6.22022, -0.185357, 0.944124),  // far bump-out side
	vec4(1.0, 1.0, -2.27414, 1.0),             // end
	vec4(1.0, -7.99628, -2.27414, 0.944124)    // far end
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Anti-aliased mask for |d| < half_w
float band(float d, float half_w) {
	float aa = max(fwidth(d), 1e-6);
	return 1.0 - smoothstep(half_w - aa * 0.5, half_w + aa * 0.5, abs(d));
}

// Signed distance to a capsule of half-length h along the first axis
float capsule(vec2 p, float h, float r) {
	return length(vec2(max(abs(p.x) - h, 0.0), p.y)) - r;
}

float fill(float sdf) {
	float aa = max(fwidth(sdf), 1e-6);
	return 1.0 - smoothstep(-aa * 0.5, aa * 0.5, sdf);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
			length(MODEL_MATRIX[2].xyz));
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Top surface and the slab's edges are resin
	float top = max(step(0.7, world_n.y), step(0.995, local_pos.y));

	// Work surface: glossy black resin with a faint speckle
	float speckle = hash(floor(local_pos.xz * 140.0));
	vec3 resin = resin_color + vec3(0.03, 0.02, 0.02) * step(0.985, speckle);

	// Find which face this is and where along it we are
	bool facing_x = abs(local_normal.x) > abs(local_normal.z);
	float axis = facing_x ? 0.0 : 1.0;
	float plane = facing_x ? local_pos.x : local_pos.z;
	float u_local = facing_x ? local_pos.z : local_pos.x;
	float u_scale = facing_x ? scale.z : scale.x;
	vec2 run = vec2(0.0);
	bool found = false;
	for (int i = 0; i < FACE_COUNT; i++) {
		vec4 f = FACES[i];
		if (!found && f.x == axis && abs(plane - f.y) < 0.02
				&& u_local > f.z - 0.02 && u_local < f.w + 0.02) {
			run = f.zw;
			found = true;
		}
	}
	if (!found) {
		run = vec2(u_local - 100.0, u_local + 100.0);
	}

	// Lay doors out between the frame strips
	float len = (run.y - run.x) * u_scale - 2.0 * stile;
	float p = (u_local - run.x) * u_scale - stile;
	float count = max(1.0, round(len / door_width));
	float has_doors = (found && len > door_width * 0.6) ? 1.0 : 0.0;
	float dw = len / count;
	float idx = clamp(floor(p / dw), 0.0, count - 1.0);
	float cu = p - idx * dw;
	bool in_run = p > 0.0 && p < len;
	// One drawer spans each pair of doors (an odd door at the end gets its own)
	float d_start = floor(idx / 2.0) * 2.0 * dw;
	float d_w = min(2.0 * dw, len - d_start);
	float dcu = p - d_start;

	float y = local_pos.y * scale.y;
	float y_top = scale.y;
	float y_drawer = drawer_line * scale.y;
	float y_toe = toe_kick_top * scale.y;
	float y_reveal = y_top - 0.004;

	// Gaps around every door and drawer front
	bool in_drawer = y > y_drawer;
	float d_vert = in_run
			? (in_drawer ? min(dcu, d_w - dcu) : min(cu, dw - cu))
			: min(abs(p), abs(p - len));
	float groove = band(d_vert, gap * 0.5) * step(y_toe, y) * step(y, y_reveal);
	groove = max(groove, band(y - y_drawer, gap * 0.5) * float(in_run));
	groove = max(groove, band(y - y_reveal, gap * 0.5));
	groove = max(groove, band(y - y_toe, gap * 0.5));
	groove *= has_doors;

	// Soft bevel on each front: lit along its top edge, shaded along the
	// bottom and sides
	float to_side = in_run ? d_vert : 1.0;
	float lo = y < y_drawer ? y_toe : y_drawer;
	float hi = y < y_drawer ? y_drawer : y_reveal;
	float bevel = 1.0;
	bevel -= 0.10 * smoothstep(0.008, 0.0, to_side);
	bevel -= 0.12 * smoothstep(0.008, 0.0, y - lo);
	bevel += 0.08 * smoothstep(0.006, 0.0, hi - y);
	bevel = mix(1.0, bevel, has_doors * step(y_toe, y));
	float tint = (hash(vec2(idx, floor(plane * 10.0))) - 0.5) * 0.03 * has_doors;

	// Pulls. Doors pair up with pulls next to the shared gap; an odd door
	// at the end of a run opens toward its neighbour.
	float pulls_on = has_doors * float(in_run);
	bool odd = mod(idx, 2.0) > 0.5 || (mod(count, 2.0) > 0.5 && idx > count - 1.5);
	float door_pull_u = odd ? pull_inset : dw - pull_inset;
	float door_pull_y = y_drawer - 0.014 - door_pull_length * 0.5;
	vec2 dp = vec2(y - door_pull_y, cu - door_pull_u);
	float drawer_half = min(d_w * 0.2, 0.04);
	float drawer_pull_y = (y_drawer + y_reveal) * 0.5;
	vec2 wp = vec2(dcu - d_w * 0.5, y - drawer_pull_y);

	float door_sdf = capsule(dp, door_pull_length * 0.5, pull_radius);
	float drawer_sdf = capsule(wp, drawer_half, pull_radius);
	float pull = max(fill(door_sdf), fill(drawer_sdf)) * pulls_on;
	// Contact shadow cast down onto the front by the bar's standoff
	vec2 sh = vec2(0.0, 0.0035);
	float shadow = max(
			1.0 - smoothstep(0.0, 0.003, capsule(dp + sh.yx, door_pull_length * 0.5, pull_radius)),
			1.0 - smoothstep(0.0, 0.003, capsule(wp + sh, drawer_half, pull_radius)));
	shadow *= pulls_on * (1.0 - pull);

	vec3 cabinet = mix(cabinet_color + vec3(tint), toe_kick_color, step(y, y_toe));
	// The toe-kick is recessed, so it darkens toward the top under the doors
	cabinet *= mix(1.0, 0.65, smoothstep(y_toe - 0.012, y_toe, y) * step(y, y_toe));
	cabinet *= bevel;
	cabinet *= 1.0 - 0.35 * shadow;
	cabinet = mix(cabinet, vec3(0.3, 0.24, 0.19), groove);

	// Round the bar: tilt the normal across it so it catches light like a rod
	float in_door = step(door_sdf, drawer_sdf);
	float across = mix(wp.y, dp.y, in_door) / pull_radius;
	across = clamp(across, -0.95, 0.95);
	vec3 across_axis = in_door > 0.5
			? (facing_x ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0))
			: vec3(0.0, 1.0, 0.0);
	vec3 across_view = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(across_axis, 0.0)).xyz);
	float is_pull = pull * (1.0 - top);
	NORMAL = normalize(mix(NORMAL,
			NORMAL * sqrt(1.0 - across * across) + across_view * across, is_pull));

	vec3 col = mix(mix(cabinet, steel_color, pull), resin, top);
	ALBEDO = col;
	METALLIC = is_pull * 0.85;
	ROUGHNESS = mix(mix(0.55, 0.32, is_pull), 0.18, top);
	SPECULAR = mix(0.5, 0.9, top);
}
