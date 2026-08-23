extends CharacterBody3D

const SPEED = 1.25
const JUMP_VELOCITY = 3
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

signal item_placed(item: Node3D)

func _ready():
	add_to_group("player")
	#staminaBar.value = 100.0
	#$StaminaBar/StaminaProgressBar.value = 100.0
	#$StaminaBar/StaminaProgressBar.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pickup_prompt.visible = false

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
@onready var pickup_prompt = $PickupPrompt
@onready var pickup_prompt_label = $PickupPrompt/Label
var held_object: RigidBody3D = null

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(70))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	#if !($StaminaBar/StaminaProgressBar.value == 0):
		#if Input.is_action_pressed("jump") && is_on_floor():
			#velocity.y = JUMP_VELOCITY
			#$StaminaBar/StaminaProgressBar.value -= 55;
	#else:
		#velocity.y = 0
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace  actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
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

	if held_object:
		pickup_prompt.visible = looking_at_placemat
		pickup_prompt_label.text = "[E] Place"
	else:
		pickup_prompt.visible = looking_at_pickable
		pickup_prompt_label.text = "[E] Pick up"

	if Input.is_action_just_pressed("pick_up"):
		if held_object:
			# Drop it
			var dropped_object = held_object
			held_object.freeze = false
			held_object = null
			if looking_at_placemat:
				item_placed.emit(dropped_object)
		elif looking_at_pickable:
			held_object = hit_object
			held_object.freeze = true

	if held_object:
		held_object.global_position = %CarryObjectMarker.global_position
		held_object.global_rotation = %CarryObjectMarker.global_rotation
	
	move_and_slide()

#func _on_sprint_cooldown_timeout() -> void:
	#sprintOnCooldown == false
