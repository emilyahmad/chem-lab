class_name CookingDirector
extends Node
# Runs Recipe.STEPS. For each step: show its instruction, wait until every required item is
# on the placemat, freeze the player while the step UI runs, then put the items the next step
# doesn't need back on the counter and move on to the next instruction.

const SLOT_SPACING := 0.09 # between items on the placemat, along its long side
const RETURN_TIME := 0.5

# Step UIs by step type; each is a CanvasLayer with start(step, items) (items: name -> node)
# and a finished(score) signal
const STEP_UIS := {
	"pour": preload("res://Scripts/pour_step.gd"),
}

var player: CharacterBody3D
var ingredients: Node3D
var placemat: MeshInstance3D
var homes := {}   # item name -> where it started on the counter
var placed := {}  # item name -> true while it sits on the placemat
var step_index := -1
var in_step := false
var step_ui: CanvasLayer

func _ready() -> void:
	ingredients = get_parent().get_node("Ingredients")
	placemat = ingredients.get_node("Placemat")
	for item in ingredients.get_children():
		if item is RigidBody3D:
			homes[item.name] = item.global_transform
	player = get_tree().get_first_node_in_group("player")
	player.item_placed.connect(_on_item_placed)
	player.item_picked.connect(_on_item_picked)
	for customer in get_tree().get_nodes_in_group("window_enemy"):
		customer.order_taken.connect(begin)

# The order was taken: start the first step
func begin() -> void:
	if step_index >= 0:
		return
	Gamestate.recipe_active = true
	Gamestate.recipe_complete = false
	Gamestate.step_scores.clear()
	_next_step()

func _next_step() -> void:
	step_index += 1
	if step_index >= Recipe.STEPS.size():
		_return_items([])
		Gamestate.cooking_prompt = ""
		Gamestate.recipe_active = false
		Gamestate.recipe_complete = true
		return
	var step: Dictionary = Recipe.STEPS[step_index]
	_return_items(step["required"])
	Gamestate.cooking_prompt = step["instruction"]

func _on_item_placed(item: Node3D) -> void:
	if step_index < 0 or step_index >= Recipe.STEPS.size() or in_step:
		return
	var required: Array = Recipe.STEPS[step_index]["required"]
	if not required.has(item.name):
		return
	placed[String(item.name)] = true
	_lay_out(required)
	for item_name in required:
		if not placed.has(item_name):
			return
	_open_step(Recipe.STEPS[step_index])

func _on_item_picked(item: Node3D) -> void:
	if not in_step:
		placed.erase(String(item.name))

# Each required item has its own spot along the placemat, centred on it
func _lay_out(required: Array) -> void:
	var mesh: MeshInstance3D = placemat
	var aabb := mesh.get_aabb()
	var center := mesh.global_transform * aabb.get_center()
	var top_pad := (mesh.global_transform * Vector3(0, aabb.end.y, 0)).y - placemat.global_position.y
	var along := placemat.global_transform.basis.z.normalized()
	for i in required.size():
		var item_name: String = required[i]
		if not placed.has(item_name):
			continue
		var item: Node3D = ingredients.get_node(item_name)
		var pos := center + along * (i - (required.size() - 1) / 2.0) * SLOT_SPACING
		pos.y = homes[item_name].origin.y + top_pad
		item.global_position = pos

func _open_step(step: Dictionary) -> void:
	in_step = true
	player.controls_locked = true
	Gamestate.cooking_prompt = ""
	step_ui = STEP_UIS[step["type"]].new()
	add_child(step_ui)
	step_ui.finished.connect(_on_step_finished, CONNECT_ONE_SHOT)
	var items := {}
	for item_name in step["required"]:
		items[item_name] = ingredients.get_node(item_name)
	step_ui.start(step, items)

func _on_step_finished(score: float) -> void:
	Gamestate.step_scores.append(score)
	step_ui.queue_free()
	in_step = false
	player.controls_locked = false
	_next_step()

# Put every placed item the next step doesn't need back where it started
func _return_items(keep: Array) -> void:
	for item_name in placed.keys():
		if keep.has(item_name):
			continue
		placed.erase(item_name)
		var item: Node3D = ingredients.get_node(item_name)
		var tween := create_tween()
		tween.tween_property(item, "global_position", (homes[item_name] as Transform3D).origin, RETURN_TIME) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
