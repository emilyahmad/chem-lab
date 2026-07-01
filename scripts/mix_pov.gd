extends Node3D

var mashed = 0
var mixer_pos_up = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if mashed > 4:
		GameState.done_mashing = true
		$Mixer.visible = false
		$Bowl.visible = false

	if Input.is_action_just_pressed("space"):
		mashed = mashed + 1
		print(mashed)
		if mixer_pos_up:
			$Mixer.global_position = Vector3(2.212654, 0.950376, 1.112519)
			mixer_pos_up = false
		else:
			$Mixer.global_position = Vector3(2.212654, 1.136418, 1.112519)
			mixer_pos_up = true
