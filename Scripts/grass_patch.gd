extends MultiMeshInstance3D
# A patch of short desert grass outside the van's side window: thousands of
# tapered, curved blades in clumps, with a gentle wind sway in the shader.
# Blades are scattered in the RV's local frame (like the desert scenery) so the
# patch always starts a little out from the wall and never goes inside the van.
# Sizes are in world units (the player is ~0.45 tall). Lives on render layer 2
# so only the moonlight lights it.

const GRASS_LAYER := 2
const WALL_X := 79.0 # the window wall, in the RV model's local space
const Z_RANGE := Vector2(-335.0, 120.0) # RV-local extent along the van

@export var rv_path: NodePath = ^"../RV"
@export var clumps := 4500
@export var blades_per_clump := Vector2i(8, 14)
@export var start_distance := 0.12 # world units out from the wall
@export var depth := 2.2 # world units the patch reaches out from the wall
@export var side_margin := 0.7 # world units beyond each end of the van
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
	var wall_point := rv.global_transform * Vector3(WALL_X, 0, 0)
	var half_len := (Z_RANGE.y - Z_RANGE.x) * 0.5 * scale_factor + side_margin
	var mid_z := (Z_RANGE.x + Z_RANGE.y) * 0.5
	var centre := rv.global_transform * Vector3(WALL_X, 0, mid_z)
	centre.y = 0.0

	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.9

	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for c in clumps:
		var d := start_distance + depth * pow(rng.randf(), 1.2)
		var a := rng.randf_range(-half_len, half_len)
		var pos := centre + out_axis * d + along_axis * a
		# Patchy: thin out with distance and where the noise is low
		var density := (1.0 - d / (depth + start_distance)) * 0.5 + 0.5
		density *= clampf(noise.get_noise_2d(pos.x, pos.z) * 1.2 + 0.95, 0.0, 1.0)
		if rng.randf() > density:
			continue
		var tone := rng.randf()
		var clump_h := rng.randf_range(blade_height.x, blade_height.y)
		var n := rng.randi_range(blades_per_clump.x, blades_per_clump.y)
		for b in n:
			var p := pos + Vector3(rng.randfn(0.0, 0.025), 0.0, rng.randfn(0.0, 0.025))
			var h := clump_h * rng.randf_range(0.6, 1.2)
			var w := rng.randf_range(0.004, 0.007)
			var bs := Basis(Vector3.UP, rng.randf() * TAU) \
				* Basis(Vector3.RIGHT, rng.randf_range(0.0, 0.4)) \
				* Basis.from_scale(Vector3(w, h, h))
			xforms.append(Transform3D(bs, p))
			# Mostly green, some drier yellow-brown blades
			var dry := clampf(tone * 1.4 - 0.55 + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
			colors.append(Color(1.0, 1.0, 1.0).lerp(Color(1.35, 1.05, 0.55), dry) * rng.randf_range(0.8, 1.1))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _blade_mesh()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
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

uniform vec3 root_color : source_color = vec3(0.05, 0.1, 0.035);
uniform vec3 tip_color : source_color = vec3(0.3, 0.4, 0.14);
uniform float sway = 0.45;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 4.0 + origin.z * 3.0;
	float gust = sin(TIME * 1.7 + phase) + 0.5 * sin(TIME * 3.1 + phase * 1.7);
	VERTEX.x += gust * sway * UV.y * UV.y;
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
