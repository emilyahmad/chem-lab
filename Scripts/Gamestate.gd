extends Node

var night_number = 1
var timer = 0


var round = 0

# Cooking step state (bowl + mixer mashing at the placemat)
var bowl_placed = false
var mixer_placed = false
var mash_count = 0
var mash_target = 10
var done_mashing = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("escape"):
		get_tree().quit()
