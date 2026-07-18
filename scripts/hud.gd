extends Control

var show_mixing_instructions = false
var show_get_flask_instructions = false
var show_pour_in_beaker_instructions = false

func _ready():
	$RichTextLabel.text = "Grab your bowl and mixer and put them in your workspace"
	$RichTextLabel.position = Vector2(484.0, 868.0)

func _process(delta: float) -> void:
	if GameState.bowl_and_mixer_placed:
		show_mixing_instructions = true
		mixing_instructions()
	
	if GameState.done_mashing:
		show_get_flask_instructions = true
		get_flask_instructions()
	
	if GameState.beaker_placed:
		show_pour_in_beaker_instructions = true
		pour_in_beaker_instructions()
		
func mixing_instructions():
	show_mixing_instructions = false
	$RichTextLabel.text = "Press the space bar to mash your cough medicine"
	$RichTextLabel.position = Vector2(484.0, 28.0)

func get_flask_instructions():
	show_get_flask_instructions = false
	$RichTextLabel.text = "Grab the beaker to pour your mixed contents into"
	$RichTextLabel.position = Vector2(484.0, 28.0)

func pour_in_beaker_instructions():
	show_pour_in_beaker_instructions = false
	$RichTextLabel.text = "Pour your bowl's mixed contents into the beaker"
	$RichTextLabel.position = Vector2(484.0, 28.0)
