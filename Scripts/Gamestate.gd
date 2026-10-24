extends Node

var night_number = 1
const ROUND_TIME := 600.0 # 10:00

var timer = ROUND_TIME
var timer_running := false

func start_timer() -> void:
	timer = ROUND_TIME
	timer_running = true


var round = 0

# Cooking step state (bowl + mixer mashing at the placemat)
var bowl_placed = false
var mixer_placed = false
var mash_count = 0
var mash_target = 10
var done_mashing = false

# Set once the player first picks up the cube
var cube_picked = false

# When non-empty, the HUD shows this instead of the cooking instructions
var order_prompt = ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if timer_running:
		timer = max(timer - delta, 0.0)
		if timer <= 0.0:
			timer_running = false
	if Input.is_action_pressed("escape"):
		get_tree().quit()
