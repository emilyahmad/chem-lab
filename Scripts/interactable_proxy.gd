extends StaticBody3D
# Forwards the player's interact calls to the node that owns this body.

var target: Node

func get_prompt() -> String:
	return target.get_prompt()

func interact() -> void:
	target.interact()
