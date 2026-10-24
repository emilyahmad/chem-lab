extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# HUD appears too early after scene transition
	$HUD.visible = false
	await get_tree().create_timer(.4).timeout
	$HUD.visible = true
	
	await get_tree().create_timer(.25).timeout
	$AnimationPlayer.play('zoom_in')
	
	await get_tree().create_timer(2.75).timeout
	SceneTransition.change_scene("res://Scenes/Gameplay/main.tscn")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
