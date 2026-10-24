extends Node3D

const MIXER_LIFT := 0.024

@onready var mixer := $Ingredients/Mixer

var mixer_rest_y := 0.0
var mixer_up := false

# Opening shot: a camera slides along the counter while the intro text plays, then
# hands over to the player's camera. Each stop is [camera position, look-at point, seconds
# to travel there], in world space.
const INTRO_PAN := [
	[Vector3(-0.4, 0.5, 1.1), Vector3(-0.03, 0.37, 0.8), 0.0],
	[Vector3(-0.4, 0.5, -0.2), Vector3(-0.03, 0.37, -0.5), 5.5],
]
const INTRO_RETURN_TIME := 1.5

var intro_camera: Camera3D
var intro_done := true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Round 1-3 is the HUD's intro text; round 4 starts the cooking timer
	Gamestate.round = 1

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.item_placed.connect(_on_item_placed)
		player.controls_locked = true
		_play_intro_pan(player)

func _play_intro_pan(player: Node3D) -> void:
	intro_done = false
	var player_mesh: Node3D = player.get_node("MeshInstance3D")
	player_mesh.visible = false
	intro_camera = Camera3D.new()
	intro_camera.near = 0.01
	add_child(intro_camera)
	_aim_camera(INTRO_PAN[0][0], INTRO_PAN[0][1])
	intro_camera.make_current()

	var tween := create_tween()
	for i in range(1, INTRO_PAN.size()):
		tween.tween_method(_aim_camera_pair.bind(INTRO_PAN[i - 1], INTRO_PAN[i]), 0.0, 1.0, INTRO_PAN[i][2]) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var player_cam: Camera3D = player.camera
	var last: Array = INTRO_PAN[INTRO_PAN.size() - 1]
	var end := [player_cam.global_position, player_cam.global_position - player_cam.global_transform.basis.z, INTRO_RETURN_TIME]
	tween.tween_method(_aim_camera_pair.bind(last, end), 0.0, 1.0, INTRO_RETURN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	player_mesh.visible = true
	player_cam.make_current()
	intro_camera.queue_free()
	intro_done = true

func _aim_camera_pair(t: float, from: Array, to: Array) -> void:
	_aim_camera((from[0] as Vector3).lerp(to[0], t), (from[1] as Vector3).lerp(to[1], t))

func _aim_camera(pos: Vector3, target: Vector3) -> void:
	intro_camera.global_position = pos
	intro_camera.look_at(target)

func _on_item_placed(item: Node3D) -> void:
	match item.name:
		"Bowl":
			if not Gamestate.bowl_placed:
				item.freeze = true
				item.global_position = %BowlSlot.global_position
				item.global_rotation = %BowlSlot.global_rotation
				Gamestate.bowl_placed = true
		"Mixer":
			if Gamestate.bowl_placed and not Gamestate.mixer_placed:
				item.freeze = true
				item.global_position = %MixerSlot.global_position
				item.global_rotation = %MixerSlot.global_rotation
				mixer_rest_y = item.global_position.y
				Gamestate.mixer_placed = true

func _unhandled_input(event: InputEvent) -> void:
	if not (Gamestate.mixer_placed and not Gamestate.done_mashing):
		return

	if event.is_action_pressed("space"):
		mixer_up = not mixer_up
		mixer.global_position.y = mixer_rest_y + (MIXER_LIFT if mixer_up else 0.0)
		Gamestate.mash_count += 1
		if Gamestate.mash_count >= Gamestate.mash_target:
			Gamestate.done_mashing = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Intro text finished: hand control to the player and start the round
	if Gamestate.round == 3 and intro_done:
		Gamestate.round = 4
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.controls_locked = false
