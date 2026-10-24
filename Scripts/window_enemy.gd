extends Node3D
# A figure that shambles in from the desert and stops right outside the van's
# side window. It's a billboarded sprite on render layer 2 (like the desert
# scenery) so only the moonlight touches it. Swap `texture` for real art.

const DESERT_LAYER := 2

const DIALOGUE_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")

const ORDER_DIALOGUE := [
	{"speaker": "Customer", "text": "Hey. You're the one who cooks around here, right?"},
	{"speaker": "Customer", "text": "I need something made. Can you cook it for me?", "choices": [
		{"text": "Sure. Give me a few minutes."},
		{"text": "What's in it for me?", "reply": [
			{"speaker": "Customer", "text": "I'll make it worth your while."},
			{"speaker": "Player", "text": "...Fine. I'll do it."},
		]},
		{"text": "I'm busy. Find someone else.", "reply": [
			{"speaker": "Customer", "text": "There is no one else. Please."},
			{"speaker": "Player", "text": "...Fine. Give me a few minutes."},
		]},
	]},
	{"speaker": "Customer", "text": "I'll wait right here."},
]

signal arrived

@export var rv_path: NodePath = ^"../RV"
@export var window_path: NodePath = ^"../VanWindow"
@export var texture: Texture2D
@export var height := 0.75 # world units; the window's top edge is ~0.8 above the sand
@export var start_delay := 0.0
@export var start_distance := 1.2 # how far out from the wall it starts
@export var start_side_offset := 6.0 # how far along the van it starts, left or right
@export var walk_speed := 0.45
@export var stop_distance := 0.1 # gap left between the sprite and the glass

var sprite: Sprite3D
var from: Vector3
var to: Vector3
var travelled := 0.0
var length := 0.0
var walking := false
var van_window: Node
var dialogue_box: CanvasLayer
var waiting_for_window := false

func _ready() -> void:
	var rv: Node3D = get_node(rv_path)
	van_window = get_node(window_path)
	# Same window geometry as desert.gd: wall plane x = 79, window centred at z = -107
	var out := (rv.global_transform.basis.orthonormalized() * Vector3.RIGHT)
	out.y = 0.0
	out = out.normalized()
	var window := rv.global_transform * Vector3(79, 0, -107)
	window.y = 0.0
	# Comes in from the left or right end of the van
	var side := out.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)

	to = window + out * stop_distance
	from = window + out * start_distance + side * start_side_offset
	length = from.distance_to(to)

	sprite = Sprite3D.new()
	sprite.texture = texture if texture else _placeholder_texture()
	sprite.pixel_size = height / sprite.texture.get_height()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.layers = DESERT_LAYER
	sprite.offset = Vector2(0, sprite.texture.get_height() / 2.0) # feet at the node's origin
	sprite.visible = false
	add_child(sprite)
	global_position = from

	dialogue_box = DIALOGUE_SCENE.instantiate()
	add_child(dialogue_box)
	van_window.fully_opened.connect(_on_window_opened)

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	sprite.visible = true
	walking = true

func _process(delta: float) -> void:
	if not walking:
		return
	travelled = minf(travelled + walk_speed * delta, length)
	global_position = from.lerp(to, travelled / length)
	# Little lurching bob while it walks
	sprite.position.y = absf(sin(travelled * 14.0)) * 0.012
	if travelled >= length:
		walking = false
		sprite.position.y = 0.0
		_on_arrived()

func _on_arrived() -> void:
	arrived.emit()
	if van_window.fully_open:
		_start_dialogue()
	else:
		waiting_for_window = true
		Gamestate.order_prompt = "A customer has arrived, open the window to take their order"

func _on_window_opened() -> void:
	if waiting_for_window:
		_start_dialogue()

func _start_dialogue() -> void:
	waiting_for_window = false
	Gamestate.order_prompt = ""
	dialogue_box.start(ORDER_DIALOGUE)

# Placeholder: a dark hunched silhouette with pale eyes
func _placeholder_texture() -> Texture2D:
	var w := 48
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body := Color(0.07, 0.07, 0.09)
	var cx := w / 2.0
	for y in h:
		for x in w:
			var dx := (x - cx) / (w / 2.0)
			var inside := false
			if y < 26: # head
				var dy := (y - 14.0) / 13.0
				inside = dx * dx * 1.4 + dy * dy < 1.0
			elif y < 34: # neck
				inside = absf(dx) < 0.22
			elif y < 66: # torso and arms, tapering down
				inside = absf(dx) < lerpf(0.95, 0.6, (y - 34.0) / 32.0)
			else: # legs
				inside = absf(dx) > 0.12 and absf(dx) < 0.55
			if inside:
				img.set_pixel(x, y, body)
	for ex in [cx - 5, cx + 5]:
		for ey in [12, 13]:
			for ox in 2:
				img.set_pixel(int(ex) + ox, ey, Color(0.95, 0.95, 0.8))
	return ImageTexture.create_from_image(img)
