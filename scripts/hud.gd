extends Control

func _ready():
	$RichTextLabel.text = "grab your bowl and mixer and put them in your workspace"
	$RichTextLabel.position = Vector2(484.0, 868.0)
	pass

func _process(delta: float) -> void:
	if GameState.bowl_and_mixer_placed:
		$RichTextLabel.text = "press the space bar to mash your cough medicine"
		$RichTextLabel.position = Vector2(484.0, 28.0)
