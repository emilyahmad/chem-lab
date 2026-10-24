extends CharacterBody3D

const SPEED = 1.25
# Player is scaled 0.25, so this is roughly a 0.6 m hop
const JUMP_VELOCITY = 1.7

const MAX_STAMINA := 100.0
const JUMP_STAMINA_COST := 30.0
const STAMINA_REGEN := 25.0 # per second
const STAMINA_REGEN_DELAY := 0.8 # seconds after use before regen starts
const SPRINT_STAMINA_DRAIN := 25.0 # per second
const SPRINT_MIN_STAMINA := 20.0 # needed to start sprinting again after running out
const SPRINT_VELOCITY = 1.5

#var sprintOnCooldown = false
#@onready var cooldown = $SprintCooldown

var sensitivity = 0.003
@onready var camera = $PlayerCamera

#@onready var staminaBar = $Player/StaminaBar/StaminaProgressBar

var exhausted = true
var exhaust_buffer = 3
var stamina_timer = 0
var can_start_timer = true

var stamina := MAX_STAMINA
var regen_cooldown := 0.0
var sprint_exhausted := false
@onready var stamina_bar: ProgressBar = %StaminaBar

signal item_placed(item: Node3D)
signal item_picked(item: Node3D)
signal item_swapped(put_down: Node3D, picked_up: Node3D)
signal dish_served

# Set by cutscenes/dialogue to stop movement and look input
var controls_locked := false
# Set by the dialogue box, which uses the jump key to continue
var jump_blocked := false
# Set by the dialogue box, whose choices are navigated with the arrow keys; while set,
# only WASD moves the player
var move_blocked := false

func _ready():
	add_to_group("player")
	#staminaBar.value = 100.0
	#$StaminaBar/StaminaProgressBar.value = 100.0
	#$StaminaBar/StaminaProgressBar.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Movement input read from WASD only, ignoring the arrow keys bound to the same actions
func _wasd_vector() -> Vector2:
	return Vector2(
		int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	).limit_length(1.0)

func _process(delta: float) -> void:
	if Input.is_action_pressed("escape"):
		get_tree().quit()

	#if exhausted == false && $StaminaBar/StaminaProgressBar.value != 100 or $StaminaBar/StaminaProgressBar.value == 0:
		#can_start_timer = true
		#if can_start_timer:
			#$StaminaBar/StaminaProgressBar.visible = true
			#stamina_timer += delta
			#if stamina_timer >= exhaust_buffer:
				#exhausted = true
				#can_start_timer = false
##				fade out?
				#$StaminaBar/StaminaProgressBar.visible = false
				#stamina_timer = 0
	#if $StaminaBar/StaminaProgressBar.value == 100:
		#exhausted = false
	#if exhausted == true:
		#$StaminaBar/StaminaProgressBar.value += .5

@onready var raycast = $PlayerCamera/RayCast3D
var held_object: RigidBody3D = null
@onready var interact_label: Label = %Label

func _unhandled_input(event):
	if controls_locked:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(70))

const HELD_SCALE := 1.5
const MIXER_CARRY_DROP := 0.17 # the pestle's origin is far below its body, so lower it to bring the body into view
const HELD_LERP_SPEED := 18.0

func _grab(item: RigidBody3D) -> void:
	held_object = item
	item_picked.emit(item)
	if item.name == "Cube":
		Gamestate.cube_picked = true
	item.set_meta("home_transform", item.global_transform)
	item.set_meta("rest_scale", item.scale)
	item.set_meta("rest_layer", item.collision_layer)
	item.freeze = true
	# Off all layers so the held item doesn't block the pickup ray or the player
	item.collision_layer = 0

# Puts the held item back down. It stays frozen, so it sticks where it lands: by
# default its original spot, keeping the orientation it had when picked up
# (never tipped over).
func _release_held(at: Variant = null) -> void:
	var item := held_object
	held_object = null
	var home: Transform3D = item.get_meta("home_transform")
	item.scale = item.get_meta("rest_scale")
	item.global_transform = home if at == null else Transform3D(home.basis, at)
	item.collision_layer = item.get_meta("rest_layer")
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	item.freeze = true

# Names that don't read right when derived from the node name
const DISPLAY_NAMES := {"Erlenmeyer": "erlenmeyer flask"}

# "CoffeeFilter" -> "coffee filter"
func _display_name(node: Node) -> String:
	if DISPLAY_NAMES.has(String(node.name).rstrip("0123456789")):
		return DISPLAY_NAMES[String(node.name).rstrip("0123456789")]
	if "label_text" in node and node.label_text != "":
		return node.label_text
	var raw := String(node.name).rstrip("0123456789")
	var out := ""
	for i in raw.length():
		var c := raw[i]
		if i > 0 and c != c.to_lower():
			out += " "
		out += c.to_lower()
	return out


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if controls_locked:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Handle jump
	if Input.is_action_just_pressed("jump") and not jump_blocked and is_on_floor() and stamina >= JUMP_STAMINA_COST:
		velocity.y = JUMP_VELOCITY
		stamina -= JUMP_STAMINA_COST
		regen_cooldown = STAMINA_REGEN_DELAY

	# Sprint drains stamina; once it hits zero, wait until some has regenerated
	var input_dir := _wasd_vector() if move_blocked else Input.get_vector("left", "right", "up", "down")
	if sprint_exhausted and stamina >= SPRINT_MIN_STAMINA:
		sprint_exhausted = false
	var sprinting := Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO \
			and not sprint_exhausted and stamina > 0.0
	if sprinting:
		stamina = maxf(stamina - SPRINT_STAMINA_DRAIN * delta, 0.0)
		regen_cooldown = STAMINA_REGEN_DELAY
		if stamina == 0.0:
			sprint_exhausted = true

	regen_cooldown = maxf(regen_cooldown - delta, 0.0)
	if regen_cooldown == 0.0:
		stamina = minf(stamina + STAMINA_REGEN * delta, MAX_STAMINA)
	stamina_bar.value = stamina
	# Only show the bar while it's depleted or recovering
	stamina_bar.visible = stamina < MAX_STAMINA

	#if !($StaminaBar/StaminaProgressBar.value == 0):
		#if Input.is_action_pressed("jump") && is_on_floor():
			#velocity.y = JUMP_VELOCITY
			#$StaminaBar/StaminaProgressBar.value -= 55;
	#else:
		#velocity.y = 0
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace  actions with custom gameplay actions.
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		var speed := SPEED * (SPRINT_VELOCITY if sprinting else 1.0)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# add timer (plus bar at the bottom/show tired)
		#if !($StaminaBar/StaminaProgressBar.value == 0):
			#if Input.is_action_pressed("sprint"):
				#velocity.z *= SPRINT_VELOCITY
				#velocity.x *= SPRINT_VELOCITY
				#$StaminaBar/StaminaProgressBar.value -= 10;
		#else:
			#velocity.x = move_toward(velocity.x, 0, 3.5)
			#velocity.z = move_toward(velocity.z, 0, 3.5)

	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	var hit_object = raycast.get_collider() if raycast.is_colliding() else null
	var looking_at_pickable = hit_object != null and hit_object.is_in_group("pickable")
	var looking_at_placemat = hit_object != null and hit_object.is_in_group("placemat")
	var looking_at_interactable = hit_object != null and hit_object.is_in_group("interactable")

	# The finished dish can be handed to the customer through the open window
	var serving: bool = held_object != null and held_object.name == "PetriDish" and Gamestate.recipe_complete \
			and looking_at_interactable and hit_object.has_method("accepts_dish") and hit_object.accepts_dish()

	if held_object:
		if serving:
			interact_label.text = "[E] Hand over the dish"
		elif looking_at_placemat:
			interact_label.text = "[E] Place"
		elif looking_at_pickable:
			interact_label.text = "[E] Swap for " + _display_name(hit_object)
		else:
			interact_label.text = "[E] Drop"
		interact_label.visible = true
	elif looking_at_interactable:
		interact_label.text = hit_object.get_prompt()
		interact_label.visible = true
	else:
		interact_label.text = "[E] Pick up" + ((" " + _display_name(hit_object)) if looking_at_pickable else "")
		interact_label.visible = looking_at_pickable

	# Clicking a clickable interactable (the posters) works like pressing E on it
	var clicked: bool = Input.is_action_just_pressed("click") and not held_object \
			and looking_at_interactable and hit_object.has_method("clickable") and hit_object.clickable()

	if Input.is_action_just_pressed("pick_up") or clicked:
		if serving:
			_release_held()
			dish_served.emit()
		elif held_object and looking_at_pickable:
			# Swap: the held item takes the other item's spot
			# (same x/z, but at the height the held item rests at)
			var other = hit_object
			var held_home: Transform3D = held_object.get_meta("home_transform")
			var spot: Vector3 = other.global_position
			spot.y = held_home.origin.y
			item_swapped.emit(held_object, other)
			_release_held(spot)
			_grab(other)
			# The held item took the other's spot, so the other's home is where it came from
			# (otherwise putting it down lands it on top of the item it was swapped with)
			other.set_meta("home_transform", Transform3D(other.global_transform.basis, held_home.origin))
		elif held_object:
			var dropped_object = held_object
			_release_held()
			if looking_at_placemat:
				item_placed.emit(dropped_object)
		elif looking_at_pickable:
			_grab(hit_object)
		elif looking_at_interactable:
			hit_object.interact()

	if held_object:
		var t := clampf(HELD_LERP_SPEED * delta, 0.0, 1.0)
		var carry_pos: Vector3 = %CarryObjectMarker.global_position
		if held_object.get("kind") == "mixer":
			carry_pos.y -= MIXER_CARRY_DROP * held_object.get_meta("rest_scale").x * HELD_SCALE
		held_object.global_position = held_object.global_position.lerp(carry_pos, t)
		var target_basis: Basis = %CarryObjectMarker.global_transform.basis.orthonormalized()
		# Labeled beakers carry their label on local -x; turn that side toward the camera (+z of the marker)
		if "label_text" in held_object and held_object.label_text != "":
			target_basis = target_basis * Basis(Vector3.UP, deg_to_rad(90))
		held_object.global_transform.basis = held_object.global_transform.basis.orthonormalized().slerp(target_basis, t).scaled(Vector3.ONE * held_object.get_meta("rest_scale").x * HELD_SCALE)

	move_and_slide()

#func _on_sprint_cooldown_timeout() -> void:
	#sprintOnCooldown == false
