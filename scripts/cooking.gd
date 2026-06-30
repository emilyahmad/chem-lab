extends Node3D

var open_window_pos = Vector3(-2.046472, 4.24953, 0.722781)
var closed_window_pos = Vector3(-2.046472, 1.845929, 0.722781)

var bowl_placed := false
var mixer_placed := false

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

func _on_bowl_body_entered(body: Node) -> void:
	if body.name == "PlacematBody":
		bowl_placed = true
		_check_both_placed()

func _on_mixer_body_entered(body: Node) -> void:
	if body.name == "PlacematBody":
		mixer_placed = true
		_check_both_placed()

func _check_both_placed() -> void:
	if bowl_placed and mixer_placed:
		var both_placed = true
		GameState.bowl_and_mixer_placed = true
		print("bowl and mixer are placed!")
		
