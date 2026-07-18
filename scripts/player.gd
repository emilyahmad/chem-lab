extends CharacterBody3D

const SPEED = 8.0
const JUMP_VELOCITY = 3
const SPRINT_VELOCITY = 1.5
const CAMERA_SENS = .003

var sensitivity = 0.003
@onready var camera = $Camera3D

var mixer_pos_up = false
var picked_object
var mashed = 0

var can_move = true
var lock_player = false

func _ready():
	add_to_group("player")
	$CanvasLayer.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	$MixPOV.visible = false
	
	$BeakerPOV.visible = false

func _input(event):
	if event.is_action_pressed("quit"): get_tree().quit()
	
	if event is InputEventMouseMotion and can_move:
		rotation.y -= event.relative.x * CAMERA_SENS
		rotation.x -= event.relative.y * CAMERA_SENS
	
	if event.is_action_pressed("pick_up") and picked_object:
		picked_object.reparent(get_tree().current_scene)
		picked_object = null

func _process(delta: float) -> void:	
	if !can_move:
		velocity = Vector3.ZERO
		global_position = Vector3(2.149029, 1.259467, 1.005127)
		rotation = Vector3(0.0, 0.0, 0.0)

	if Input.is_action_pressed("escape"):
		get_tree().quit()
	
	if GameState.done_mashing:
		can_move = true
		
	if GameState.bowl_and_mixer_placed and !lock_player:
		lock_player = true
		$MixPOV.visible = true
		can_move = false
	
	if GameState.beaker_placed and !lock_player:
		lock_player = true
		$BeakerPOV.visible = true
		

@onready var raycast = $Camera3D/RayCast3D
var held_object: RigidBody3D = null

func _unhandled_input(event):
	if event is InputEventMouseMotion && can_move:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(70))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if can_move:
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	
	var hit_object = raycast.get_collider()
	if raycast.is_colliding() && hit_object.is_in_group("pickable"):
		$CanvasLayer.show()
	else:
		$CanvasLayer.hide()
	
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
