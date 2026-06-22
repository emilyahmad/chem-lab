extends Node3D

var open_window_pos = Vector3(-2.046472, 4.24953, 0.722781)
var closed_window_pos = Vector3(-2.046472, 1.845929, 0.722781)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#print($Window.global_position)
	$Window.global_position = open_window_pos


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if Input.is_action_just_pressed("close_window"):
		$Window.global_position = closed_window_pos
		
	if Input.is_action_just_pressed("open_window"):
		$Window.global_position = open_window_pos


func _on_bowl_reference_body_exited(body: Node) -> void:
	print("collided with ", body.name)
