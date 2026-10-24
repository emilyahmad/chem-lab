class_name CookingDirector
extends Node
# Runs Recipe.STEPS. For each step: show its instruction, wait until every required item is
# on the placemat, freeze the player while the step UI runs, then put the items the next step
# doesn't need back on the counter and move on to the next instruction.

const SLOT_GAP := 0.02 # between items on the placemat, along its long side
const RETURN_TIME := 0.5
const START_PROMPT_TIME := 2.5 # how long "let's get cooking" shows before the first instruction
const BASE_PAY := 200.0 # a perfect batch of full size
const FAST_TIME := 60.0 # seconds; a cook this quick or quicker earns the full speed bonus
const SLOW_TIME := 180.0 # seconds; a cook this slow or slower earns no speed bonus
const MAX_SPEED_BONUS := 0.5 # extra payout fraction for the fastest cooks
const CAM_FOV := 60.0 # horizontal
const CAM_MARGIN := 1.0 # how much wider than the placemat's long side the view is
const CAM_TILT := 50.0 # degrees off straight down, leaning toward the screen-bottom side
const STEP_NAMES := ["Pouring", "Crushing", "Combining", "Heating", "Dosing", "Crystals"]

# Step UIs by step type; each is a CanvasLayer with start(step, items) (items: name -> node)
# and a finished(score) signal
const STEP_UIS := {
	"pour": preload("res://Scripts/pour_step.gd"),
	"crush": preload("res://Scripts/crush_step.gd"),
	"combine": preload("res://Scripts/combine_step.gd"),
	"heat": preload("res://Scripts/heat_step.gd"),
	"drop": preload("res://Scripts/drop_step.gd"),
	"crystallize": preload("res://Scripts/crystal_step.gd"),
}

var player: CharacterBody3D
var ingredients: Node3D
var placemat: MeshInstance3D
var homes := {}   # item name -> where it started on the counter
var originals := {} # item name -> {scene, props} to rebuild it as new
var placed := {}  # item name -> true while it sits on the placemat
var step_index := -1
var return_tweens := {} # item name -> its running tween back to the counter
var in_step := false
var step_ui: CanvasLayer
var cook_camera: Camera3D
var cook_start_msec := 0

func _ready() -> void:
	ingredients = get_parent().get_node("Ingredients")
	placemat = ingredients.get_node("Placemat")
	for item in ingredients.get_children():
		if item is RigidBody3D:
			homes[item.name] = item.global_transform
			var props := {}
			for p in ["kind", "label_text", "contents_color", "contents_powder"]:
				props[p] = item.get(p)
			originals[item.name] = {"scene": item.scene_file_path, "props": props}
	player = get_tree().get_first_node_in_group("player")
	player.item_placed.connect(_on_item_placed)
	player.item_picked.connect(_on_item_picked)
	player.item_swapped.connect(_on_item_swapped)
	for customer in get_tree().get_nodes_in_group("window_enemy"):
		customer.order_taken.connect(begin)
		customer.served.connect(reset)

# The order was taken: start the first step
func begin() -> void:
	if step_index >= 0 or Gamestate.recipe_active:
		return
	Gamestate.recipe_active = true
	Gamestate.recipe_complete = false
	Gamestate.step_scores.clear()
	Gamestate.cooking_prompt = "Alright, let's get cooking"
	await get_tree().create_timer(START_PROMPT_TIME).timeout
	cook_start_msec = Time.get_ticks_msec()
	_next_step()

# Extra payout fraction for cooking quickly: full bonus at FAST_TIME, none at SLOW_TIME
func _speed_bonus(cook_time: float) -> float:
	return MAX_SPEED_BONUS * clampf((SLOW_TIME - cook_time) / (SLOW_TIME - FAST_TIME), 0.0, 1.0)

# Purity is the average of the step scores; the payout also depends on the batch size and cook time
func _grade() -> void:
	Gamestate.cooking_prompt = ""
	var total := 0.0
	for score in Gamestate.step_scores:
		total += score
	Gamestate.last_purity = total / maxf(Gamestate.step_scores.size(), 1)
	var cook_time := (Time.get_ticks_msec() - cook_start_msec) / 1000.0
	var speed_bonus := _speed_bonus(cook_time)
	Gamestate.last_payout = roundi(BASE_PAY * Gamestate.last_purity * Gamestate.batch_yield * (1.0 + speed_bonus))
	player.controls_locked = true
	var card := GradeCard.new()
	add_child(card)
	card.show_result(Gamestate.last_purity, Gamestate.batch_yield, Gamestate.last_payout, cook_time, speed_bonus, STEP_NAMES, Gamestate.step_scores)
	await card.closed
	card.queue_free()
	player.controls_locked = false
	Gamestate.recipe_active = false
	Gamestate.recipe_complete = true

# The dish has been served: ready for the next order
func reset() -> void:
	step_index = -1
	placed.clear()
	in_step = false
	Gamestate.orders_served += 1
	Gamestate.recipe_complete = false
	Gamestate.step_scores.clear()
	_restock()

# Swap every ingredient for a fresh copy on its starting spot (liquids, powders and tilts reset)
func _restock() -> void:
	for tween in return_tweens.values():
		(tween as Tween).kill()
	return_tweens.clear()
	for item_name in originals:
		var old := ingredients.get_node_or_null(NodePath(item_name))
		if old:
			old.name = String(item_name) + "_old"
			old.queue_free()
		var fresh: RigidBody3D = (load(originals[item_name]["scene"]) as PackedScene).instantiate()
		fresh.name = item_name
		for prop in originals[item_name]["props"]:
			fresh.set(prop, originals[item_name]["props"][prop])
		fresh.transform = ingredients.global_transform.affine_inverse() * homes[item_name]
		ingredients.add_child(fresh)

func _next_step() -> void:
	step_index += 1
	if step_index >= Recipe.STEPS.size():
		_return_items([])
		_grade()
		return
	var step: Dictionary = Recipe.STEPS[step_index]
	_return_items(step["required"])
	Gamestate.cooking_prompt = step["instruction"]

func _on_item_placed(item: Node3D) -> void:
	if step_index < 0 or step_index >= Recipe.STEPS.size() or in_step:
		return
	var required: Array = Recipe.STEPS[step_index]["required"]
	if not required.has(item.name):
		Gamestate.alert_requested.emit("Wrong ingredient!")
		return
	placed[String(item.name)] = true
	_lay_out(required)
	for item_name in required:
		if not placed.has(item_name):
			return
	_open_step(Recipe.STEPS[step_index])

func _on_item_picked(item: Node3D) -> void:
	# A return tween still running would keep dragging the item out of the player's hands
	if return_tweens.has(item.name):
		(return_tweens[item.name] as Tween).kill()
		return_tweens.erase(item.name)
	if not in_step:
		placed.erase(String(item.name))

# Swapping with an item that sits on the placemat: the item put down takes its slot
func _on_item_swapped(put_down: Node3D, picked_up: Node3D) -> void:
	if in_step or step_index < 0 or step_index >= Recipe.STEPS.size():
		return
	if placed.has(String(picked_up.name)):
		# The player releases the item after this signal, so place it once that is done
		_on_item_placed.call_deferred(put_down)

# Each required item has its own spot along the placemat, sized to the item and centred as a row
func _lay_out(required: Array) -> void:
	var mesh: MeshInstance3D = placemat
	var aabb := mesh.get_aabb()
	var center := mesh.global_transform * aabb.get_center()
	var top_pad := (mesh.global_transform * Vector3(0, aabb.end.y, 0)).y - placemat.global_position.y
	var along := placemat.global_transform.basis.z.normalized()
	var halves: Array[float] = []
	var total := SLOT_GAP * (required.size() - 1)
	for item_name in required:
		halves.append(_half_width(ingredients.get_node(item_name)))
		total += halves[-1] * 2.0
	var offset := -total / 2.0
	for i in required.size():
		var item_name: String = required[i]
		offset += halves[i]
		if placed.has(item_name):
			var pos := center + along * offset
			pos.y = homes[item_name].origin.y + top_pad
			ingredients.get_node(item_name).global_position = pos
		offset += halves[i] + SLOT_GAP

# Half the item's footprint, from the widest of its meshes
func _half_width(item: Node3D) -> float:
	var widest := 0.0
	for mi in item.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (item.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		widest = maxf(widest, maxf(box.size.x, box.size.z))
	return widest / 2.0

func _open_step(step: Dictionary) -> void:
	in_step = true
	player.controls_locked = true
	_enter_cook_view()
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
	_exit_cook_view()
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
		return_tweens[item.name] = tween

# Switch to a bird's-eye camera over the placemat, with the player's capsule hidden
func _enter_cook_view() -> void:
	# Aim at the middle of the items, not the placemat; the placemat only widens the framing
	var bounds: AABB
	for item_name in Recipe.STEPS[step_index]["required"]:
		var item_bounds := _world_bounds(ingredients.get_node(item_name))
		bounds = item_bounds if bounds.size == Vector3.ZERO else bounds.merge(item_bounds)
	var center := bounds.get_center()
	bounds = bounds.merge(_world_bounds(placemat))
	var along := placemat.global_transform.basis.z.normalized()
	var long_side := maxf(bounds.size.dot(along.abs()), 0.0)
	var height := long_side * CAM_MARGIN * 0.5 / tan(deg_to_rad(CAM_FOV / 2.0))
	cook_camera = Camera3D.new()
	cook_camera.keep_aspect = Camera3D.KEEP_WIDTH
	cook_camera.fov = CAM_FOV
	cook_camera.near = 0.01
	add_child(cook_camera)
	# Up on screen is the placemat's short side, so its long side runs left to right
	var screen_up := -placemat.global_transform.basis.x.normalized()
	var tilt := deg_to_rad(CAM_TILT)
	cook_camera.global_position = center + (Vector3.UP * cos(tilt) - screen_up * sin(tilt)) * height
	cook_camera.look_at(center, screen_up)
	cook_camera.make_current()
	player.get_node("MeshInstance3D").visible = false

# World-space box around every mesh under the node (including the node itself)
func _world_bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi: MeshInstance3D in meshes:
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _exit_cook_view() -> void:
	player.camera.make_current()
	player.get_node("MeshInstance3D").visible = true
	cook_camera.queue_free()
