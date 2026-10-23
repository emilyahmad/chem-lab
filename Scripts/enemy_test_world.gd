extends Node3D

const CUSTOMER_SCENE = preload("res://Scenes/Gameplay/customer.tscn")

const SPAWN_DELAY := 2.0
const SPAWN_DISTANCE := 8.0
const SPAWN_ARC := 50.0 # degrees either side of where the player is looking

const ORDER_DIALOGUE := [
	{"speaker": "Customer", "text": "Hey. You're the one who cooks around here, right?"},
	{"speaker": "Customer", "text": "I need something made. Can you cook it for me?", "choices": [
		{"text": "Sure. Give me a few minutes."},
		{"text": "What's in it for me?", "reply": [
			{"speaker": "Customer", "text": "I'll make it worth your while."},
			{"speaker": "Player", "text": "...Fine. I'll do it."},
		]},
		{"text": "I'm busy. Find someone else.", "reply": [
			{"speaker": "Customer", "text": "There is no one else. Please."},
			{"speaker": "Player", "text": "...Fine. Give me a few minutes."},
		]},
	]},
	{"speaker": "Customer", "text": "I'll wait right here. Come find me when it's done."},
]

const HANDOFF_DIALOGUE := [
	{"speaker": "Player", "text": "Here you go. Fresh."},
	{"speaker": "Customer", "text": "Perfect. This is exactly what I needed.", "choices": [
		{"text": "Happy to help."},
		{"text": "That'll cost you extra.", "reply": [
			{"speaker": "Customer", "text": "Ha. Fair enough."},
		]},
	]},
	{"speaker": "Customer", "text": "Pleasure doing business."},
]

@onready var player: CharacterBody3D = $Player
@onready var dialogue_box = $DialogueBox

var customer

func _ready() -> void:
	Gamestate.done_mashing = false
	await get_tree().create_timer(SPAWN_DELAY).timeout
	_spawn_customer()

# Stand-in for finishing the cooking steps, which this scene doesn't have
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		Gamestate.done_mashing = true

func _spawn_customer() -> void:
	# Spawn somewhere ahead of the player so it's seen walking up
	var angle := deg_to_rad(randf_range(-SPAWN_ARC, SPAWN_ARC))
	var forward := -player.global_transform.basis.z
	var offset := forward.rotated(Vector3.UP, angle) * SPAWN_DISTANCE
	customer = CUSTOMER_SCENE.instantiate()
	# Position before adding to the tree, or the body briefly exists at the origin on top of the player
	customer.position = Vector3(player.global_position.x + offset.x, player.global_position.y, player.global_position.z + offset.z)
	add_child(customer)
	customer.target = player
	customer.reached_player.connect(_start_order_dialogue)
	customer.dish_handed_over.connect(_start_handoff_dialogue)

func _run_dialogue(lines: Array, on_done: Callable) -> void:
	player.controls_locked = true
	dialogue_box.finished.connect(on_done, CONNECT_ONE_SHOT)
	dialogue_box.start(lines)

func _start_order_dialogue() -> void:
	_run_dialogue(ORDER_DIALOGUE, _on_order_given)

func _end_dialogue() -> void:
	player.controls_locked = false

func _on_order_given() -> void:
	_end_dialogue()
	customer.waiting_for_dish = true

func _start_handoff_dialogue() -> void:
	_run_dialogue(HANDOFF_DIALOGUE, _on_handoff_done)

func _on_handoff_done() -> void:
	_end_dialogue()
