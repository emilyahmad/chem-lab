extends Node3D

var open_window_pos = Vector3(-1.99298, 2.85601, -0.391589)
var closed_window_pos = Vector3(-1.99298, 1.08476, -0.391589)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Window.global_position = open_window_pos


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("close_window"):
		print("closing window..")
		$Window.global_position = closed_window_pos
		
	if Input.is_action_just_pressed("open_window"):
		print("opening window..")
		$Window.global_position = open_window_pos
