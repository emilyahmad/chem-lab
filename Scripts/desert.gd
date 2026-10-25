extends Node3D
# Moonlit desert outside the van's side window: sand, saguaro and barrel
# cacti, prickly pears, rocks, shrubs, tumbleweeds, dunes and far-off mesas,
# scattered in a fan in front of the window with a fixed seed. Sizes are in
# world units (the player is ~0.45 tall, so a 1.2 saguaro stands ~5 m tall).
#
# Everything sits on render layer 2, which only the moonlight lights, so the
# van's interior lighting is left alone.

const DESERT_LAYER := 2
const WALL_X := 79.0 # RV-local x of the side walls
const VAN_Z := Vector2(-335.0, 120.0) # RV-local extent along the van
const WEED_INTERVAL := Vector2(15.0, 30.0) # seconds between tumbleweeds
const FOG_BANK_COUNT := 140
# Average colour of the night-sky panorama just above the horizon, so the fog
# and its banks fade into the background instead of standing out against it
const SKY_HORIZON := Color(0.33, 0.31, 0.31)
const DUST := Color(0.41, 0.34, 0.29) # fog banks: the sky tinted a little dusty orange
const FOG_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, blend_mix;

uniform sampler2D noise : repeat_enable;
uniform vec4 tint : source_color = vec4(0.4, 0.46, 0.62, 1.0);
uniform float opacity = 0.6;
uniform float scroll = 0.012; // noise drift along the quad's width (screen-horizontal = parallel to the van)
uniform float softness = 0.2; // radial fade start (0 = all fade, 1 = hard edge)
instance uniform vec2 seed = vec2(0.0);

void vertex() {
	// Face the camera, keeping the node's scale
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length((UV - 0.5) * vec2(2.0, 2.4));
	float mask = 1.0 - smoothstep(softness, 1.0, d);
	float n = texture(noise, UV * 0.8 + seed + vec2(TIME * scroll, 0.0)).r;
	float a = smoothstep(0.38, 0.78, n) * mask * opacity;
	ALBEDO = tint.rgb * (0.8 + 0.4 * n);
	ALPHA = a;
}
"""

const SAND := Color(0.62, 0.5, 0.36)
const CACTUS := Color(0.2, 0.36, 0.22)
const ROCK := Color(0.36, 0.3, 0.27)
const SHRUB := Color(0.3, 0.32, 0.2)
const WEED := Color(0.5, 0.38, 0.22)
const MESA_BANDS := [Color(0.55, 0.3, 0.2), Color(0.66, 0.42, 0.28), Color(0.5, 0.26, 0.19), Color(0.7, 0.5, 0.34)]

@export var rv_path: NodePath = ^"../RV"
@export var ground_path: NodePath = ^"../Ground"
@export var world_env_path: NodePath = ^"../../WorldEnvironment"
@export var seed_value := 4
# Fog thick enough that customers walking off (5-8 m out) fade from view
@export var fog_density := 0.32
@export var fog_color := SKY_HORIZON
# Scatter all the way round the van (not just in front of the window), keeping
# clear of the van's own footprint. For views that look at the van from outside.
@export var surround := false

var rng := RandomNumberGenerator.new()
var window_pos: Vector3
var weeds: Array[Dictionary] = []
var next_weed := 4.0
var rv: Node3D
var facing: Vector3 # horizontal direction the side window looks out along

func _ready() -> void:
	rng.seed = seed_value
	rv = get_node(rv_path)
	facing = (rv.global_transform.basis.orthonormalized() * Vector3.RIGHT)
	facing.y = 0.0
	facing = facing.normalized()
	window_pos = rv.global_transform * Vector3(79, 0, -107)
	window_pos.y = 0.0

	_build_ground()
	_build_moon()
	_build_fog()

	var k := 2 if surround else 1 # more of everything when it's spread round the van
	for i in 14 * k:
		_saguaro(_spot(1.6, 11.0, 55.0))
	for i in 18 * k:
		_barrel(_spot(0.9, 7.0, 55.0))
	for i in 10 * k:
		_prickly_pear(_spot(0.9, 8.0, 55.0))
	for i in 70 * k:
		_rock(_spot(0.9, 14.0, 60.0), rng.randf_range(0.03, 0.2))
	for i in 55 * k:
		_shrub(_spot(0.9, 12.0, 60.0))
	for i in 10 * k:
		_dune(_spot(10.0, 40.0, 70.0))
	for i in 8 * k:
		_mesa(_spot(28.0, 75.0, 70.0))
	# Last, so the seeded scenery layout above is unchanged
	_build_fog_banks()

# --- environment -----------------------------------------------------------

func _build_ground() -> void:
	var sand := StandardMaterial3D.new()
	sand.albedo_color = SAND
	sand.roughness = 1.0
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	sand.albedo_texture = tex
	sand.uv1_triplanar = true
	sand.uv1_scale = Vector3(0.6, 0.6, 0.6)

	var ground: MeshInstance3D = get_node_or_null(ground_path)
	if ground:
		ground.material_override = sand
		ground.layers |= DESERT_LAYER

	# Endless sand out to the horizon, a hair below the walkable ground
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200, 1200)
	var mi := _instance(plane, sand, Vector3(0, -0.004, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_moon() -> void:
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.35
	moon.light_cull_mask = DESERT_LAYER
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 25.0
	add_child(moon)
	# Low and slightly behind the viewer's left, so the scenery is side-lit
	var dir := (-facing + Vector3(0, -0.7, 0.0)).rotated(Vector3.UP, deg_to_rad(-35.0)).normalized()
	moon.look_at_from_position(window_pos + Vector3(0, 10, 0), window_pos + Vector3(0, 10, 0) + dir)

func _build_fog() -> void:
	var we: WorldEnvironment = get_node_or_null(world_env_path)
	if we == null or we.environment == null:
		return
	var env := we.environment
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sky_affect = 0.0

# One giant, thick, static dust cloud lying on the ground in front of the
# window (many overlapping banks), so customers walking away fade into it. It
# ignores the scene fog and stays outside the van's walls. Soft camera-facing quads masked by fractal noise.
func _build_fog_banks() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.012
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256

	var shader := Shader.new()
	shader.code = FOG_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("noise", tex)
	mat.set_shader_parameter("tint", DUST)
	mat.set_shader_parameter("opacity", 1.0)

	var quad := QuadMesh.new()
	for i in FOG_BANK_COUNT:
		var pos := _spot(3.5, 14.0, 60.0)
		var size := Vector2(rng.randf_range(8.0, 18.0), rng.randf_range(9.0, 16.0))
		pos.y = size.y * 0.5 - 0.1 # sits on the ground
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.layers = DESERT_LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3(size.x, size.y, 1.0)
		mi.position = pos
		mi.set_instance_shader_parameter("seed", Vector2(rng.randf(), rng.randf()))
		add_child(mi)

# --- placement helpers -----------------------------------------------------

# A random ground point in a fan in front of the window
func _spot(min_dist: float, max_dist: float, half_angle_deg: float) -> Vector3:
	if surround:
		return _surround_spot(min_dist, max_dist)
	var d := lerpf(min_dist, max_dist, pow(rng.randf(), 1.4))
	var a := deg_to_rad(rng.randf_range(-half_angle_deg, half_angle_deg))
	var dir := facing.rotated(Vector3.UP, a)
	return window_pos + dir * d

# Scenery laid out parallel to the van instead of fanned from the window: a
# distance out from the nearest wall, on either side, spread along the van's
# length and widening a little with distance so the far rows frame it.
func _surround_spot(min_dist: float, max_dist: float) -> Vector3:
	var s := rv.global_transform.basis.get_scale().x
	var along := rv.global_transform.basis.orthonormalized() * Vector3.BACK
	along.y = 0.0
	along = along.normalized()
	var centre := rv.global_transform * Vector3(0, 0, (VAN_Z.x + VAN_Z.y) * 0.5)
	centre.y = 0.0
	var half_len := (VAN_Z.y - VAN_Z.x) * 0.5 * s
	var half_wide := WALL_X * s
	var d := lerpf(min_dist, max_dist, pow(rng.randf(), 1.4))
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var reach := half_len + d * 0.6
	return centre + facing * side * (half_wide + d) + along * rng.randf_range(-reach, reach)

func _mat(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _instance(mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.layers = DESERT_LAYER
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 4
	return m

func _sphere(radius: float, squash_y := 1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 * squash_y
	m.radial_segments = 14
	m.rings = 7
	return m

# --- features --------------------------------------------------------------

func _saguaro(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = rng.randf() * TAU
	add_child(root)
	var green := _mat(CACTUS)
	var h := rng.randf_range(0.5, 1.2)
	var r := h * 0.07
	_instance(_capsule(r, h), green, Vector3(0, h * 0.5, 0), Vector3.ZERO, root)
	for side in [-1.0, 1.0]:
		if rng.randf() < 0.35:
			continue
		var arm_y := h * rng.randf_range(0.35, 0.6)
		var reach := h * rng.randf_range(0.16, 0.24)
		var rise := h * rng.randf_range(0.2, 0.34)
		var ar := r * 0.72
		_instance(_capsule(ar, reach + ar * 2.0), green, Vector3(side * reach * 0.5, arm_y, 0), Vector3(0, 0, 90), root)
		_instance(_capsule(ar, rise + ar * 2.0), green, Vector3(side * reach, arm_y + rise * 0.5, 0), Vector3.ZERO, root)

func _barrel(at: Vector3) -> void:
	var r := rng.randf_range(0.03, 0.06)
	var root := Node3D.new()
	root.position = at
	add_child(root)
	_instance(_sphere(r, 1.2), _mat(CACTUS.lightened(0.05)), Vector3(0, r * 1.1, 0), Vector3.ZERO, root)
	if rng.randf() < 0.5:
		var bloom := CylinderMesh.new()
		bloom.top_radius = r * 0.35
		bloom.bottom_radius = r * 0.35
		bloom.height = r * 0.15
		_instance(bloom, _mat(Color(0.85, 0.35, 0.45)), Vector3(0, r * 2.2, 0), Vector3.ZERO, root)

func _prickly_pear(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = rng.randf() * TAU
	add_child(root)
	var green := _mat(CACTUS.lightened(0.08))
	var s := rng.randf_range(0.05, 0.09)
	var low := Vector3(0, s * 0.8, 0)
	var pad := _sphere(s, 0.25)
	_instance(pad, green, low, Vector3(0, 0, 80), root)
	_instance(_sphere(s * 0.8, 0.25), green, low + Vector3(s * 0.5, s * 0.9, 0), Vector3(0, 0, 25), root)
	_instance(_sphere(s * 0.7, 0.25), green, low + Vector3(-s * 0.4, s * 1.1, 0), Vector3(0, 0, -30), root)

func _rock(at: Vector3, size: float) -> void:
	var mi := _instance(_sphere(size, 0.7), _mat(ROCK.lightened(rng.randf_range(-0.05, 0.1))), at + Vector3(0, size * 0.3, 0))
	mi.scale = Vector3(rng.randf_range(0.8, 1.5), rng.randf_range(0.7, 1.1), rng.randf_range(0.8, 1.4))
	mi.rotation.y = rng.randf() * TAU

func _shrub(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var mat := _mat(SHRUB.lightened(rng.randf_range(-0.05, 0.08)))
	var s := rng.randf_range(0.04, 0.1)
	for i in 3:
		var off := Vector3(rng.randf_range(-s, s), 0, rng.randf_range(-s, s))
		_instance(_sphere(s * rng.randf_range(0.6, 1.0), 0.65), mat, off + Vector3(0, s * 0.35, 0), Vector3.ZERO, root)

# A dense ball of dry, branching stems. Returns {root, ball}; the ball is
# what spins while the root travels.
func _make_tumbleweed(r: float) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var ball := Node3D.new()
	root.add_child(ball)
	var mat := _mat(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	var mi := MeshInstance3D.new()
	mi.mesh = _tumbleweed_mesh(r)
	mi.material_override = mat
	mi.layers = DESERT_LAYER
	mi.scale = Vector3(1.0, 0.85, 1.0) # a little squashed, like a real one
	ball.add_child(mi)
	return {"root": root, "ball": ball}

# Stems grow from the core in wandering, tapering curves, then wrap round
# inside the outer shell, throwing off short twigs; the shell ends up a dense
# interlaced mesh with a sparser, darker core.
func _tumbleweed_mesh(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := r * 0.13
	for s in 70:
		var pos := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * r * 0.25
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var pts: Array[Vector3] = [pos]
		var steps := randi_range(10, 18)
		for i in steps:
			dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.55).normalized()
			if pos.length() > r * 0.75:
				# Near the shell: turn along it and curl back inward
				var n := pos.normalized()
				dir = (dir - n * (dir.dot(n) + 0.35)).normalized()
			pos = (pos + dir * step).limit_length(r)
			pts.append(pos)
			if i > 3 and randf() < 0.35:
				_tumbleweed_twig(st, pos, dir, r, step)
		var thick := r * randf_range(0.022, 0.035)
		_stem(st, pts, thick, thick * 0.3, _weed_tone())
	return st.commit()

func _tumbleweed_twig(st: SurfaceTool, from: Vector3, dir: Vector3, r: float, step: float) -> void:
	var pos := from
	var d := (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))).normalized()
	var pts: Array[Vector3] = [pos]
	for i in randi_range(2, 4):
		d = (d + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.5).normalized()
		pos = (pos + d * step * 0.7).limit_length(r)
		pts.append(pos)
	_stem(st, pts, r * 0.012, r * 0.004, _weed_tone())

# Sun-bleached straw through to dry reddish brown
func _weed_tone() -> Color:
	return WEED.lerp(Color(0.72, 0.6, 0.42), randf()).darkened(randf_range(0.0, 0.12)).lightened(0.08)

# A tapering three-sided tube through pts, framed by parallel transport so it
# doesn't twist
func _stem(st: SurfaceTool, pts: Array[Vector3], r0: float, r1: float, color: Color) -> void:
	const SIDES := 3
	var tangent := (pts[1] - pts[0]).normalized()
	var normal := tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT).normalized()
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	for i in pts.size():
		var next_t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		normal = (normal - next_t * normal.dot(next_t)).normalized()
		tangent = next_t
		var binormal := tangent.cross(normal)
		var radius := lerpf(r0, r1, float(i) / (pts.size() - 1))
		var ring := PackedVector3Array()
		var ns := PackedVector3Array()
		for k in SIDES:
			var a := TAU * k / SIDES
			var n := normal * cos(a) + binormal * sin(a)
			ring.append(pts[i] + n * radius)
			ns.append(n)
		rings.append(ring)
		ring_normals.append(ns)
	st.set_color(color)
	for i in pts.size() - 1:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			for v in [[i, k], [i + 1, k], [i + 1, k2], [i, k], [i + 1, k2], [i, k2]]:
				st.set_normal(ring_normals[v[0]][v[1]])
				st.add_vertex(rings[v[0]][v[1]])

# Every 15-30 s a tumbleweed blows across the view, bouncing as it rolls
func _process(delta: float) -> void:
	next_weed -= delta
	if next_weed <= 0.0:
		next_weed = randf_range(WEED_INTERVAL.x, WEED_INTERVAL.y)
		_spawn_tumbleweed()
	for i in range(weeds.size() - 1, -1, -1):
		var w := weeds[i]
		w.t += delta * w.speed
		var root: Node3D = w.root
		var pos: Vector3 = w.from.lerp(w.to, clampf(w.t / w.length, 0.0, 1.0))
		pos.y = w.r + absf(sin(w.t * w.hop_rate + w.phase)) * w.r * 0.9
		root.position = pos
		w.ball.global_rotate(w.axis, delta * w.speed / w.r)
		if w.t >= w.length:
			root.queue_free()
			weeds.remove_at(i)

func _spawn_tumbleweed() -> void:
	var r := randf_range(0.1, 0.17)
	var side := 1.0 if randf() < 0.5 else -1.0
	var lateral := facing.cross(Vector3.UP).normalized() * side
	var out := randf_range(2.0, 5.5)
	var half := 14.0
	var base := window_pos + facing * out
	var parts := _make_tumbleweed(r)
	weeds.append({
		"root": parts.root, "ball": parts.ball, "r": r,
		"from": base - lateral * half, "to": base + lateral * half,
		"length": half * 2.0, "t": 0.0, "speed": randf_range(1.6, 2.6),
		"hop_rate": randf_range(5.0, 8.0), "phase": randf() * TAU,
		"axis": Vector3.UP.cross(lateral).normalized(),
	})

func _dune(at: Vector3) -> void:
	var w := rng.randf_range(6.0, 16.0)
	var mi := _instance(_sphere(w, 0.12), _mat(SAND.darkened(0.08), 1.0), at + Vector3(0, 0, 0))
	mi.scale = Vector3(1.0, 1.0, rng.randf_range(0.5, 1.0))
	if surround:
		# Long axis runs parallel to the van
		var along := rv.global_transform.basis.orthonormalized() * Vector3.BACK
		mi.rotation.y = atan2(-along.z, along.x) + rng.randf_range(-0.2, 0.2)
	else:
		mi.rotation.y = facing.signed_angle_to(Vector3.RIGHT, Vector3.UP) + rng.randf_range(-0.4, 0.4)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# Flat-topped butte: a few stacked, slightly tapering bands of rock
func _mesa(at: Vector3) -> void:
	var w := rng.randf_range(4.0, 9.0)
	var bands := rng.randi_range(3, 4)
	var y := 0.0
	var radius := w
	for i in bands:
		var h := rng.randf_range(1.0, 2.2)
		var m := CylinderMesh.new()
		m.bottom_radius = radius
		m.top_radius = radius * (0.9 if i < bands - 1 else 0.97)
		m.height = h
		m.radial_segments = 10
		m.rings = 1
		var mi := _instance(m, _mat(MESA_BANDS[i % MESA_BANDS.size()]), at + Vector3(0, y + h * 0.5, 0))
		mi.scale = Vector3(1.0, 1.0, 0.6)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		y += h
		radius *= 0.9
