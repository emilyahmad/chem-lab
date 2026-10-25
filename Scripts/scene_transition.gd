extends CanvasLayer

func change_scene(target: String) -> void:
	await cover()
	get_tree().change_scene_to_file(target)
	reveal()

# Dissolves to black and waits for it to finish
func cover() -> void:
	$AnimationPlayer.play('dissolve')
	await $AnimationPlayer.animation_finished

# Dissolves back from black
func reveal() -> void:
	$AnimationPlayer.play_backwards('dissolve')
