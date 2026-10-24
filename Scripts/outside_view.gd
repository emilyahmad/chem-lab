extends Node3D

const MAIN_SCENE := "res://Scenes/Gameplay/main.tscn"

var leaving := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# HUD appears too early after scene transition
	$HUD.visible = false
	if not await _wait(.4): return
	$HUD.visible = true
	
	if not await _wait(.25): return
	$AnimationPlayer.play('zoom_in')

	# First lines of the intro; the rest play over the pan in the van (hud.gd)
	$HUD.instructions_label.text = "Welcome to the van and your personal lab."
	if not await _wait(2.25): return
	$HUD.instructions_label.text = "You have 10 minutes"
	if not await _wait(1.5): return
	$HUD.instructions_label.text = "to serve as many customers as you can."
	if not await _wait(2.25): return
	_leave(false)

# Returns false if the player skipped while waiting
func _wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds).timeout
	return not leaving

func _leave(skipped := true) -> void:
	if leaving:
		return
	leaving = true
	Gamestate.skip_van_intro = skipped
	SceneTransition.change_scene(MAIN_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("space"):
		get_viewport().set_input_as_handled()
		_leave()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
