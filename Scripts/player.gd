extends CharacterBody3D

const SPEED = 8.0
const JUMP_VELOCITY = 3
const SPRINT_VELOCITY = 1.5
const CAMERA_SENS = .003

#var sprintOnCooldown = false
#@onready var cooldown = $SprintCooldown

var sensitivity = 0.003
@onready var camera = $Camera3D

@onready var staminaBar = $Player/StaminaBar/StaminaProgressBar

var exhausted = true
var exhaust_buffer = 3
var stamina_timer = 0
var can_start_timer = true

var mixer_pos_up = false
var picked_object
var mashed = 0

func _ready():
	add_to_group("player")
	#staminaBar.value = 100.0
	#$StaminaBar/StaminaProgressBar.value = 100.0
	#$StaminaBar/StaminaProgressBar.visible = false
	
	# change to false when leave testing
	#GameState.done_mashing = false
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event.is_action_pressed("quit"): get_tree().quit()
	
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * CAMERA_SENS
		rotation.x -= event.relative.y * CAMERA_SENS
	
	if event.is_action_pressed("pick_up") and picked_object:
		picked_object.reparent(get_tree().current_scene)
		picked_object = null

func _reset():
	print("calling")
	process_mode = PROCESS_MODE_INHERIT
		
	$MixPOV.process_mode = PROCESS_MODE_INHERIT
	$MixPOV/Bowl.process_mode = PROCESS_MODE_INHERIT
	$MixPOV/Mixer.process_mode = PROCESS_MODE_INHERIT

func _process(delta: float) -> void:
	pass
	#if GameState.done_mashing:
		#_reset()
#
	#if GameState.bowl_and_mixer_placed:
		#$MixPOV.visible = true
		## stop player from moving
		#global_position = Vector3(2.149029, 1.259467, 1.005127)
		#rotation = Vector3(0.0, 0.0, 0.0)
		#process_mode = PROCESS_MODE_DISABLED
		#
		#$MixPOV.process_mode = PROCESS_MODE_ALWAYS
		#$MixPOV/Bowl.process_mode = PROCESS_MODE_ALWAYS
		#$MixPOV/Mixer.process_mode = PROCESS_MODE_ALWAYS
		##process_mode = PROCESS_MODE_DISABLED
		##$MixPOV.process_mode = PROCESS_MODE_ALWAYS
		##$MixPOV/Bowl.process_mode = PROCESS_MODE_ALWAYS
		##$MixPOV/Mixer.process_mode = PROCESS_MODE_ALWAYS

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

@onready var raycast = $Camera3D/RayCast3D
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
	
	var hit_object = raycast.get_collider()
	if raycast.is_colliding() && hit_object.is_in_group("pickable"):
		$CanvasLayer.show()
	else:
		pass
	
	if Input.is_action_just_pressed("pick_up"):
		if held_object:
			# Drop it
			held_object.freeze = false
			held_object = null
		elif raycast.is_colliding():
			if hit_object.is_in_group("pickable"):
				held_object = hit_object
				held_object.freeze = true

	if held_object:
		held_object.global_position = %CarryObjectMarker.global_position
		held_object.global_rotation = %CarryObjectMarker.global_rotation
	
	move_and_slide()
	
	# Controlling Mix POV
	#if Input.is_action_just_pressed("space"):
		#mashed = mashed + 1
		#if mixer_pos_up:
			#$MixPOV/Mixer.global_position = Vector3(2.212654, 0.950376, 1.112519)
			#mixer_pos_up = false
		#else:
			#$MixPOV/Mixer.global_position = Vector3(2.212654, 1.136418, 1.112519)
			#mixer_pos_up = true

#func _on_sprint_cooldown_timeout() -> void:
	#sprintOnCooldown == false
