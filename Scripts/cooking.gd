extends Node3D

const MIXER_LIFT := 0.05

@onready var mixer := $Ingredients/Mixer

var mixer_rest_y := 0.0
var mixer_up := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Gamestate.round = 4

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.item_placed.connect(_on_item_placed)

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
	pass
