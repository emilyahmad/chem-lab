extends Node

var night_number = 1
const ROUND_TIME := 600.0 # 10:00

var timer = ROUND_TIME
var timer_running := false

func start_timer() -> void:
	timer = ROUND_TIME
	timer_running = true


var round = 0

# Set when the player skips the opening scene, so the van intro is skipped too
var skip_van_intro := false

# Asks the HUD to flash a short temporary message in the top left
signal alert_requested(text: String)

# Cooking progress, driven by cooking_director.gd
var cooking_prompt = "" # instruction for the current recipe step, shown by the HUD
var recipe_active = false # an order is being cooked
var recipe_complete = false
var step_scores: Array = [] # 0..1 accuracy per finished step
var batch_yield = 0.0 # 0..1 size of the batch, set when the crystals are harvested
var last_purity = 0.0 # 0..1 grade of the dish waiting to be served
var last_payout = 0
var money = 0
var orders_served = 0 # finished orders; the cooking instructions stop after the first

# Set once the player first picks up the cube
var cube_picked = false

# Set by the dialogue box while it's open; the HUD hides the instructions meanwhile
var in_dialogue = false

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
