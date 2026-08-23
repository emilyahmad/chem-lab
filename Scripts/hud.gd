extends CanvasLayer

@onready var instructions_label : RichTextLabel = %Instructions
@onready var timer_label : RichTextLabel = $Navbar/Timer

const ROUND_TIME := 240.0 # 4:00

var timer_running := false
var cooking_started := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	instructions_label.text = ""
	Gamestate.timer = ROUND_TIME
	_update_timer_label()

func _process(delta: float) -> void:
	if Gamestate.round == 0:
		instructions_label.text = "Survive each night by cooking crystals before the time runs out!"

	if Gamestate.round == 1:
		Gamestate.round = 2
		instructions_label.text = ""
		await get_tree().create_timer(.6).timeout
		instructions_label.text = "Welcome to the van and your personal lab"
		await get_tree().create_timer(2.5).timeout
		instructions_label.text = "Follow the instructions before the time runs out"
		await get_tree().create_timer(2.75).timeout
		instructions_label.text = "Ready?"
		await get_tree().create_timer(1.5).timeout
		Gamestate.round = 3

	if Gamestate.round == 4:
		instructions_label.text = ""
		Gamestate.round = 5
		timer_running = true
		await get_tree().create_timer(1.).timeout
		cooking_started = true

	if timer_running:
		Gamestate.timer = max(Gamestate.timer - delta, 0.0)
		_update_timer_label()
		if Gamestate.timer <= 0.0:
			timer_running = false
			cooking_started = false
			instructions_label.text = "Time's up!"

	if cooking_started:
		_update_cooking_instructions()

func _update_cooking_instructions() -> void:
	if Gamestate.done_mashing:
		instructions_label.text = "The mixture is ready!"
	elif Gamestate.mixer_placed:
		instructions_label.text = "Press [SPACE] to work the mixer (%d/%d)" % [Gamestate.mash_count, Gamestate.mash_target]
	elif Gamestate.bowl_placed:
		instructions_label.text = "Grab the mixer and set it on the placemat, over the bowl"
	else:
		instructions_label.text = "Grab the bowl and set it on the placemat"

func _update_timer_label() -> void:
	var seconds_left := int(ceil(Gamestate.timer))
	var minutes := int(seconds_left / 60.0)
	var seconds := seconds_left % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]
