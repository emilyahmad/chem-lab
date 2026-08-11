extends CanvasLayer

@onready var instructions_label : RichTextLabel = %Instructions


# grab and display
# my_label.text = f"Current Score: {score}"
var get = Gamestate.night_number
var also = Gamestate.timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	instructions_label.text = "Survive each night by cooking crystals before the time runs out!"

func _process(delta: float) -> void:
	if Gamestate.round == 1:
		Gamestate.round = 2
		instructions_label.text = ""
		await get_tree().create_timer(1.5).timeout
		instructions_label.text = "Welcome to the van and your personal lab"
		await get_tree().create_timer(3).timeout
		instructions_label.text = "Follow the instructions before the time runs out"
		await get_tree().create_timer(3).timeout
		instructions_label.text = "Ready?"
