extends Camera3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# for rotating camera with keys
# tut: https://www.youtube.com/watch?v=KLPmIYVPcjg
#func _input(event):
	#if Input.is_key_pressed(KEY_E):
		#rotate_y(0.1)
	#if Input.is_key_pressed(KEY_R):
		#rotate_y(-0.1)
	#if Input.is_key_pressed(KEY_F):
		#rotate_x(0.1)
	#if Input.is_key_pressed(KEY_G):
		#rotate_x(-0.1)
