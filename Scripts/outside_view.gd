extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# HUD appears too early after scene transition
	$HUD.visible = false
	await get_tree().create_timer(.4).timeout
	$HUD.visible = true
	
	await get_tree().create_timer(.25).timeout
	$AnimationPlayer.play('zoom_in')

	# First lines of the intro; the rest play over the pan in the van (hud.gd)
	$HUD.instructions_label.text = "Welcome to the van and your personal lab."
	await get_tree().create_timer(2.25).timeout
	$HUD.instructions_label.text = "You have 10 minutes"
	await get_tree().create_timer(1.5).timeout
	$HUD.instructions_label.text = "to serve as many customers as you can."
	await get_tree().create_timer(2.25).timeout
	SceneTransition.change_scene("res://Scenes/Gameplay/main.tscn")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
