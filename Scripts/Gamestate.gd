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

# Customer names still to come before everyone's been seen and the line is
# reshuffled. Kept here (not reset by reset_run) so it survives scene reloads.
var customer_deck: Array = []
var last_customer = ""

# Run stats shown on the "You were caught." screen
var purities: Array = [] # 0..1 grade of every dish cooked this run
var best_purity = 0.0
var best_payout = 0
var total_earned = 0

# Colour of the dosing mixture after n drops, as [drops, colour] stops; rerolled per customer
var dose_stops: Array = [
	[0.0, Color(0.15, 0.4, 0.95, 0.85)],
	[6.0, Color(0.1, 0.7, 0.8, 0.85)],
	[12.0, Color(0.2, 0.85, 0.45, 0.85)],
	[18.0, Color(0.9, 0.85, 0.2, 0.85)],
	[24.0, Color(0.95, 0.5, 0.15, 0.85)],
]

# A fresh gradient: the hue walks a random distance around the wheel from a random start
func roll_dose_palette() -> void:
	var hue := randf()
	var span := randf_range(0.5, 0.9) * (1.0 if randf() < 0.5 else -1.0)
	var sat := randf_range(0.65, 0.9)
	var val := randf_range(0.85, 0.95)
	dose_stops = []
	for i in 5:
		dose_stops.append([i * 6.0, Color.from_hsv(fposmod(hue + span * i / 4.0, 1.0), sat, val, 0.85)])

func time_survived() -> float:
	return ROUND_TIME - timer

# Wipes everything a run accumulates and starts the clock again
func reset_run() -> void:
	money = 0
	orders_served = 0
	purities = []
	best_purity = 0.0
	best_payout = 0
	total_earned = 0
	step_scores = []
	batch_yield = 0.0
	last_purity = 0.0
	last_payout = 0
	cube_picked = false
	recipe_active = false
	recipe_complete = false
	in_dialogue = false
	instructions_open = false
	order_prompt = ""
	cooking_prompt = ""
	skip_van_intro = true
	roll_dose_palette()
	start_timer()

# Set once the player first picks up the cube
var cube_picked = false

# Set by the dialogue box while it's open; the HUD hides the instructions meanwhile
var in_dialogue = false

# Set by the HUD while the F-key instructions recap is open; the interact prompt hides meanwhile
var instructions_open = false

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
