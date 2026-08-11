extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# timer starts moving once arrive @ scene
		# calls to HUD
	
	Gamestate.round = 1
	#$PerspectiveCamera.current = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Gamestate.round == 3:
		# Could just switch cameras
		#%PlayerCamera.current = true
		SceneTransition.change_scene("res://Scenes/test.tscn")
