extends Node3D

@onready var dialogue_ui = get_tree().current_scene.get_node("dialogue_ui/canvas")
@onready var dialogue_animation: AnimationPlayer = get_tree().current_scene.get_node("dialogue_ui/canvas/AnimationPlayer")
@onready var speaker_name: RichTextLabel = get_tree().current_scene.get_node("dialogue_ui/canvas/speaker_name")
@onready var dialogue_text: RichTextLabel = get_tree().current_scene.get_node("dialogue_ui/canvas/dialogue_text")
# get player
@onready var player: CharacterBody3D = get_tree().current_scene.get_node("player")

@export var dialogues: Array[String]
@export var speaker_names: Array[String]
@export var speaker: Node3D
#
#var current_dialogue = -1
#var started = false

func _ready() -> void:
	pass
	#dialogue_ui.get_node("continue").connect("pressed", Callable(self, "continue_dialogue"))
#
#func start_dialogue(body):
	#if body == player and !started:
		#started = true
		#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		#player.SPEED = 0.0
		#player.get_node("CAMERA_SENS").sensitivity = 0.0
		#dialogue_ui.visible = true
		#speaker.look_at(player.global_transform.origin)
		#speaker.rotation_degrees.x = 0
		#speaker.rotation_degrees.z = 0
		#continue_dialogue()
#
#func end_dialogue():
	#player.speed = 5.0
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#player.get_node("CAMERA_SENS").sensitivity = 0.0
	#dialogue_ui.visible = false
#
#func continue_dialogue():
	#current_dialogue += 1
	#if current_dialogue < dialogues.size():
		#dialogue_text.text = dialogues[current_dialogue]
		#speaker_name.text = speaker_names[current_dialogue]
		#dialogue_animation.play("RESET")
		#dialogue_animation.play("scroll")
	#else:
		#end_dialogue()
