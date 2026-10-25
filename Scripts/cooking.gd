extends Node3D

# Opening shot: a camera creeps toward the van from outside (+X side), passes through the wall, then
# slides along the counter while the intro text plays, and finally hands over to the player's
# camera. Each stop is [camera position, look-at point, seconds to travel there], in world space.
const INTRO_PAN := [
	[Vector3(1.6, 0.12, 0.431), Vector3(0.9, 0.22, 0.431), 0.0], # low and close to the sand
	[Vector3(1.1, 0.5, 0.431), Vector3(0.3, 0.55, 0.431), 4.0], # rises to take in the van
	[Vector3(0.2315, 0.632, 0.431), Vector3(-0.769, 0.584, 0.421), 4.0],
	[Vector3(-0.4, 0.6, 1.1), Vector3(-0.03, 0.37, 0.8), 2.0],
	[Vector3(-0.4, 0.6, -0.2), Vector3(-0.03, 0.37, -0.5), 11.5],
]
const INTRO_RETURN_TIME := 2.0
const EXTERIOR_STOPS := 3 # the first stops (up to the window) are outside the van

var intro_camera: Camera3D
var intro_done := true
var intro_tween: Tween
var intro_keys: Array = []
var intro_player: Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Round 1-3 is the HUD's intro text; round 4 starts the cooking timer
	Gamestate.round = 1

	var player = get_tree().get_first_node_in_group("player")
	if player:
		add_child(CookingDirector.new())
		if Gamestate.skip_van_intro:
			# Skipped from the opening scene: go straight to gameplay
			Gamestate.skip_van_intro = false
			intro_done = true
			Gamestate.round = 3
			$HUD.intro_skipped = true
			$HUD.skip_hint.visible = false
		else:
			player.controls_locked = true
			_play_intro_pan(player)

func _play_intro_pan(player: Node3D) -> void:
	intro_done = false
	intro_player = player
	var player_mesh: Node3D = player.get_node("MeshInstance3D")
	player_mesh.visible = false
	intro_camera = Camera3D.new()
	intro_camera.near = 0.01
	add_child(intro_camera)
	_aim_camera(INTRO_PAN[0][0], INTRO_PAN[0][1])
	intro_camera.make_current()

	# Outside: one smooth move through the exterior stops, so it never stalls at the
	# waypoint where the camera finishes rising
	intro_keys = INTRO_PAN.slice(0, EXTERIOR_STOPS)
	var exterior_time := 0.0
	for i in range(1, intro_keys.size()):
		exterior_time += intro_keys[i][2]
	var tween := create_tween()
	intro_tween = tween
	tween.tween_method(_aim_along_path, 0.0, exterior_time, exterior_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Inside: an eased move to each stop in turn
	for i in range(EXTERIOR_STOPS, INTRO_PAN.size()):
		tween.tween_method(_aim_camera_pair.bind(INTRO_PAN[i - 1], INTRO_PAN[i]), 0.0, 1.0, INTRO_PAN[i][2]) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var player_cam: Camera3D = player.camera
	var last: Array = INTRO_PAN[INTRO_PAN.size() - 1]
	var end := [player_cam.global_position, player_cam.global_position - player_cam.global_transform.basis.z, INTRO_RETURN_TIME]
	tween.tween_method(_aim_camera_pair.bind(last, end), 0.0, 1.0, INTRO_RETURN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_finish_intro()

func _finish_intro() -> void:
	if intro_done:
		return
	var player_cam: Camera3D = intro_player.camera
	intro_player.get_node("MeshInstance3D").visible = true
	player_cam.make_current()
	intro_camera.queue_free()
	intro_done = true

func skip_intro() -> void:
	if intro_done:
		return
	intro_tween.kill()
	_finish_intro()

# Camera pose `time` seconds into the outside pan: a Catmull-Rom curve through the stops, with
# each segment's tangents scaled by its duration so speed carries across the stops
func _aim_along_path(time: float) -> void:
	var i := 1
	var start := 0.0
	while i < intro_keys.size() - 1 and time > start + intro_keys[i][2]:
		start += intro_keys[i][2]
		i += 1
	var dur: float = intro_keys[i][2]
	var weight := clampf((time - start) / dur, 0.0, 1.0)
	var prev_dur: float = intro_keys[i - 1][2] if i > 1 else dur
	var next_dur: float = intro_keys[i + 1][2] if i + 1 < intro_keys.size() else dur
	var before: Array = intro_keys[maxi(i - 2, 0)]
	var from: Array = intro_keys[i - 1]
	var to: Array = intro_keys[i]
	var after: Array = intro_keys[mini(i + 1, intro_keys.size() - 1)]
	var pos: Vector3 = (from[0] as Vector3).cubic_interpolate_in_time(to[0], before[0], after[0], weight, dur, -prev_dur, dur + next_dur)
	var look: Vector3 = (from[1] as Vector3).cubic_interpolate_in_time(to[1], before[1], after[1], weight, dur, -prev_dur, dur + next_dur)
	_aim_camera(pos, look)

func _aim_camera_pair(t: float, from: Array, to: Array) -> void:
	_aim_camera((from[0] as Vector3).lerp(to[0], t), (from[1] as Vector3).lerp(to[1], t))

func _aim_camera(pos: Vector3, target: Vector3) -> void:
	intro_camera.global_position = pos
	intro_camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if not intro_done and event.is_action_pressed("space"):
		skip_intro()
		get_viewport().set_input_as_handled()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Intro text finished: hand control to the player and start the round
	if Gamestate.round == 3 and intro_done:
		Gamestate.round = 4
		Gamestate.start_timer()
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.controls_locked = false
