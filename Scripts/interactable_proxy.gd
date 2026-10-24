extends StaticBody3D
# Forwards the player's interact calls to the node that owns this body.

var target: Node

func get_prompt() -> String:
	return target.get_prompt()

func interact() -> void:
	target.interact()

# Whether a finished dish can be handed over here (the window, once it's open)
func accepts_dish() -> bool:
	return target.has_method("accepts_dish") and target.accepts_dish()
