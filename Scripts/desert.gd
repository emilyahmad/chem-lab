extends Node3D
# Moonlit desert outside the van's side window: sand, saguaro and barrel
# cacti, prickly pears, rocks, shrubs, tumbleweeds, dunes and far-off mesas,
# scattered in a fan in front of the window with a fixed seed. Sizes are in
# world units (the player is ~0.45 tall, so a 1.2 saguaro stands ~5 m tall).
#
# Everything sits on render layer 2, which only the moonlight lights, so the
# van's interior lighting is left alone.

const DESERT_LAYER := 2
const WEED_INTERVAL := Vector2(15.0, 30.0) # seconds between tumbleweeds

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

var rng := RandomNumberGenerator.new()
var window_pos: Vector3
var weeds: Array[Dictionary] = []
var next_weed := 4.0
var facing: Vector3 # horizontal direction the side window looks out along

func _ready() -> void:
	rng.seed = seed_value
	var rv: Node3D = get_node(rv_path)
	facing = (rv.global_transform.basis.orthonormalized() * Vector3.RIGHT)
	facing.y = 0.0
	facing = facing.normalized()
	window_pos = rv.global_transform * Vector3(79, 0, -107)
	window_pos.y = 0.0

	_build_ground()
	_build_moon()
	_build_fog()

	for i in 14:
		_saguaro(_spot(1.6, 11.0, 55.0))
	for i in 18:
		_barrel(_spot(0.9, 7.0, 55.0))
	for i in 10:
		_prickly_pear(_spot(0.9, 8.0, 55.0))
	for i in 70:
		_rock(_spot(0.9, 14.0, 60.0), rng.randf_range(0.03, 0.2))
	for i in 55:
		_shrub(_spot(0.9, 12.0, 60.0))
	for i in 10:
		_dune(_spot(10.0, 40.0, 70.0))
	for i in 8:
		_mesa(_spot(28.0, 75.0, 70.0))

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
	env.fog_light_color = Color(0.1, 0.13, 0.22)
	env.fog_density = 0.003
	env.fog_sky_affect = 0.0

# --- placement helpers -----------------------------------------------------

# A random ground point in a fan in front of the window
func _spot(min_dist: float, max_dist: float, half_angle_deg: float) -> Vector3:
	var d := lerpf(min_dist, max_dist, pow(rng.randf(), 1.4))
	var a := deg_to_rad(rng.randf_range(-half_angle_deg, half_angle_deg))
	var dir := facing.rotated(Vector3.UP, a)
	return window_pos + dir * d

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

# A tangle of dry stems: interlocking rings. Returns {root, ball}; the ball
# is what spins while the root travels.
func _make_tumbleweed(r: float) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var ball := Node3D.new()
	root.add_child(ball)
	var mat := _mat(WEED)
	for rot in [Vector3.ZERO, Vector3(90, 0, 0), Vector3(0, 0, 90), Vector3(45, 0, 45), Vector3(-45, 30, 60), Vector3(30, 60, -45)]:
		var t := TorusMesh.new()
		t.outer_radius = r
		t.inner_radius = r * 0.94
		t.rings = 18
		t.ring_segments = 4
		_instance(t, mat, Vector3.ZERO, rot, ball)
	return {"root": root, "ball": ball}

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
