extends CanvasLayer

@onready var instructions_label : RichTextLabel = %Instructions


# grab and display
# my_label.text = f"Current Score: {score}"
var get = Gamestate.night_number
var also = Gamestate.timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	instructions_label.text = "Survive each night by cooking crystals before the time runs out!"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
