extends CharacterBody3D

signal reached_player
signal dish_handed_over

const SPEED = 1.0
const TALK_DISTANCE = 1.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: Node3D
var chasing := true

# Set by the world once the order has been given; the dish can then be handed over
var waiting_for_dish := false
var served := false

func _ready() -> void:
	add_to_group("customer")
	add_to_group("interactable")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if target == null:
		target = get_tree().get_first_node_in_group("player")

	var dir := Vector3.ZERO
	if chasing and target:
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > TALK_DISTANCE:
			dir = to_target.normalized()
		else:
			chasing = false
			reached_player.emit()
		if to_target.length() > 0.01:
			look_at(global_position + to_target, Vector3.UP)

	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()

# Interactable interface used by the player's raycast
func get_prompt() -> String:
	if not waiting_for_dish:
		return ""
	return "[E] Hand over dish" if Gamestate.recipe_complete else "Waiting for your dish..."

func interact() -> void:
	if waiting_for_dish and Gamestate.recipe_complete:
		waiting_for_dish = false
		served = true
		dish_handed_over.emit()
