extends MultiMeshInstance3D
# Short dark-orange desert grass spread across the ground round the van and
# under it: tens of thousands of tapered, curved blades in clumps, thinning
# with distance, with a gentle wind sway in the shader. Blades are scattered in
# the RV's local frame (like the desert scenery) so they follow the van.
# Sizes are in world units (the player is ~0.45 tall). Lives on render layer 2
# so only the moonlight lights it.

const GRASS_LAYER := 2
const WALL_X := 79.0 # the window wall, in the RV model's local space
const Z_RANGE := Vector2(-335.0, 120.0) # RV-local extent along the van

@export var rv_path: NodePath = ^"../RV"
@export var clumps := 140000 # target number of clumps
@export var blades_per_clump := Vector2i(6, 10)
@export var spread := 11.0 # world units the grass reaches out from the van on every side
@export var full_density_distance := 2.5 # world units from the van where it starts thinning
@export var far_density := 0.5 # density at the edge of the spread, relative to next to the van
@export var blade_height := Vector2(0.03, 0.075)
@export var seed_value := 11

func _ready() -> void:
	var rv: Node3D = get_node(rv_path)
	top_level = true
	global_transform = Transform3D.IDENTITY
	layers = GRASS_LAYER
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var scale_factor := rv.global_transform.basis.get_scale().x
	var basis := rv.global_transform.basis.orthonormalized()
	var out_axis := basis * Vector3.RIGHT
	var along_axis := basis * Vector3.BACK
	var mid_z := (Z_RANGE.x + Z_RANGE.y) * 0.5
	var centre := rv.global_transform * Vector3(0, 0, mid_z)
	centre.y = 0.0

	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.9

	# Rejection-sample clump positions over a rectangle round the van (so the
	# grass runs under it and out on every side), thinning with distance
	var half_wide := WALL_X * scale_factor
	var half_len := (Z_RANGE.y - Z_RANGE.x) * 0.5 * scale_factor
	# Per-blade transform (12 floats) + colour (4), in MultiMesh buffer
	# layout; filling this directly keeps load time down with this many blades
	var buf := PackedFloat32Array()
	var count := 0
	var accepted := 0
	var attempts := 0
	while accepted < clumps and attempts < clumps * 20:
		attempts += 1
		var across := rng.randf_range(-half_wide - spread, half_wide + spread)
		var along := rng.randf_range(-half_len - spread, half_len + spread)
		var dist := Vector2(maxf(absf(across) - half_wide, 0.0), maxf(absf(along) - half_len, 0.0)).length()
		var fade := smoothstep(full_density_distance, spread, dist)
		var density := lerpf(1.0, far_density, fade)
		var pos := centre + out_axis * across + along_axis * along
		density *= clampf(noise.get_noise_2d(pos.x, pos.z) * 1.2 + 0.95, 0.0, 1.0)
		if dist > spread or rng.randf() > density:
			continue
		accepted += 1
		var tone := rng.randf()
		var clump_h := rng.randf_range(blade_height.x, blade_height.y)
		var n := rng.randi_range(blades_per_clump.x, blades_per_clump.y)
		for b in n:
			var p := pos + Vector3(rng.randfn(0.0, 0.025), 0.0, rng.randfn(0.0, 0.025))
			var h := clump_h * rng.randf_range(0.6, 1.2)
			var w := rng.randf_range(0.005, 0.009)
			var bs := Basis(Vector3.UP, rng.randf() * TAU) \
				* Basis(Vector3.RIGHT, rng.randf_range(0.0, 0.4)) \
				* Basis.from_scale(Vector3(w, h, h))
			# Dark orange, with some blades deeper red-brown and some lighter amber
			var amber := clampf(tone + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
			var c := Color(0.8, 0.65, 0.6).lerp(Color(1.3, 1.2, 0.9), amber) * rng.randf_range(0.8, 1.1)
			buf.append_array([bs.x.x, bs.y.x, bs.z.x, p.x, bs.x.y, bs.y.y, bs.z.y, p.y,
					bs.x.z, bs.y.z, bs.z.z, p.z, c.r, c.g, c.b, c.a])
			count += 1

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _blade_mesh()
	mm.instance_count = count
	mm.buffer = buf
	multimesh = mm

# One blade, 1 unit tall and 1 unit wide at the base: tapers to a point and
# curves over along +z. UV.y runs 0 (root) to 1 (tip).
func _blade_mesh() -> ArrayMesh:
	const SEGMENTS := 5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var hw := 0.5 * (1.0 - 0.95 * pow(t, 1.4))
		var bend := 0.45 * t * t
		for side in [-1.0, 1.0]:
			verts.append(Vector3(side * hw, t, bend))
			normals.append(Vector3(0, -0.4 * t, 1).normalized())
			uvs.append(Vector2(0.5 + side * 0.5, t))
	for i in SEGMENTS:
		var a := i * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material())
	return mesh

func _material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 root_color : source_color = vec3(0.1, 0.035, 0.01);
uniform vec3 tip_color : source_color = vec3(0.55, 0.2, 0.04);
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float sway = 0.012; // tip displacement in world units
uniform float gust_speed = 1.2;

void vertex() {
	// Bend in world space, so every blade leans the same way whatever its
	// size and rotation: a steady lean, gust waves rolling across the field
	// and a little per-blade flutter
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 dir = normalize(wind_dir);
	float along = dot(origin.xz, dir);
	float wave = sin(along * 1.6 - TIME * gust_speed) * 0.5 + 0.5;
	wave *= sin(along * 0.37 + origin.x * 0.21 - TIME * gust_speed * 0.45) * 0.3 + 0.7;
	float flutter = sin(TIME * 6.0 + origin.x * 37.0 + origin.z * 23.0) * 0.18;
	float bend = (0.25 + wave + flutter) * sway * UV.y * UV.y;
	vec3 world_push = vec3(dir.x, 0.0, dir.y) * bend;
	world_push.y = -0.35 * bend * UV.y; // tips dip slightly as they lean
	// Back to blade space; the basis is rotation * scale (orthogonal columns),
	// so this is cheaper than a full inverse
	mat3 m = mat3(MODEL_MATRIX);
	VERTEX += vec3(dot(m[0], world_push) / dot(m[0], m[0]),
			dot(m[1], world_push) / dot(m[1], m[1]),
			dot(m[2], world_push) / dot(m[2], m[2]));
}

void fragment() {
	ALBEDO = mix(root_color, tip_color, smoothstep(0.0, 1.0, UV.y)) * COLOR.rgb;
	ROUGHNESS = 0.85;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
