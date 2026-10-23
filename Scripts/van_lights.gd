extends Node3D
# Small ceiling lamps down the middle of the van, so the ends the two counter
# spotlights don't reach aren't pitch black. They flicker: mostly a faint
# shimmer, with an occasional burst of stutters where a lamp nearly dies. The
# counter spotlights dip along with the lamps. Positions are in the RV model's
# local space (x across, y up, z along the van).

const LAMP_Y := 98.0 # just under the ceiling (which is at ~101)
const LAMP_Z := [-235.0, -120.0, -5.0, 95.0]
const LAMP_X := 0.0

const LAMP_COLOR := Color(1.0, 0.82, 0.62)
const LAMP_ENERGY := 0.2
const GLOW_ENERGY := 1.1
const SHIMMER := 0.06 # constant small fluctuation
const BURST_GAP := Vector2(1.5, 7.0) # seconds between stutter bursts, per lamp
const BURST_LENGTH := Vector2(0.15, 0.7)
const SPOT_FOLLOW := 0.5 # how much the counter spotlights follow the lamps

@export var rv_path: NodePath = ^"../RV"
@export var spot_paths: Array[NodePath] = [^"../SpotLight3D", ^"../SpotLight3D2"]

var lamps: Array[Dictionary] = []
var spots: Array[Dictionary] = []

func _ready() -> void:
	var rv: Node3D = get_node(rv_path)
	var frame_basis := rv.global_transform.basis.orthonormalized()
	var s := rv.global_transform.basis.get_scale().x

	for z in LAMP_Z:
		var lamp := Node3D.new()
		add_child(lamp)
		lamp.global_transform = Transform3D(frame_basis, rv.global_transform * Vector3(LAMP_X, LAMP_Y, z))

		# Little flat fixture, with its own material so it can flicker too
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.9, 0.72)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.8, 0.58)
		glow.emission_energy_multiplier = GLOW_ENERGY
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.07, 0.006, 0.022)
		mesh.material = glow
		var fixture := MeshInstance3D.new()
		fixture.mesh = mesh
		fixture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.add_child(fixture)

		var light := OmniLight3D.new()
		light.light_color = LAMP_COLOR
		light.light_energy = LAMP_ENERGY
		light.omni_range = 120.0 * s * 2.0
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.position = Vector3(0, -0.04, 0)
		lamp.add_child(light)

		lamps.append({
			"light": light, "glow": glow, "factor": 1.0,
			"next_burst": randf_range(BURST_GAP.x, BURST_GAP.y), "burst_left": 0.0,
			"stutter": 0.0, "level": 1.0,
		})

	for path in spot_paths:
		var spot: Light3D = get_node_or_null(path)
		if spot:
			spots.append({"light": spot, "base": spot.light_energy})

func _process(delta: float) -> void:
	var total := 0.0
	for l in lamps:
		if l.burst_left > 0.0:
			l.burst_left -= delta
			# Re-roll the level every few frames so it stutters rather than fades
			l.stutter -= delta
			if l.stutter <= 0.0:
				l.stutter = randf_range(0.02, 0.08)
				l.level = 1.0 if randf() < 0.3 else randf_range(0.05, 0.5)
		else:
			l.level = 1.0
			l.next_burst -= delta
			if l.next_burst <= 0.0:
				l.next_burst = randf_range(BURST_GAP.x, BURST_GAP.y)
				l.burst_left = randf_range(BURST_LENGTH.x, BURST_LENGTH.y)
		l.factor = l.level * (1.0 + randf_range(-SHIMMER, SHIMMER))
		l.light.light_energy = LAMP_ENERGY * l.factor
		l.glow.emission_energy_multiplier = GLOW_ENERGY * l.factor
		total += l.factor
	var avg := total / maxf(lamps.size(), 1)
	for sp in spots:
		sp.light.light_energy = sp.base * lerpf(1.0, avg, SPOT_FOLLOW)
