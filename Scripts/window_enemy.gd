extends Node3D
# A figure that shambles in from the desert and stops right outside the van's
# side window. It's a billboarded sprite on render layer 2 (like the desert
# scenery) so only the moonlight touches it. Swap `texture` for real art.

const DESERT_LAYER := 2

const DIALOGUE_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")

# Each customer has their own look (height multiplier and tint), order
# dialogue with its own choices, and a reaction for each grade of dish.
# "%d" in a reaction line is replaced with the payout.
const CUSTOMERS := [
	{
		"name": "Drifter", "scale": 1.0, "tint": Color(1, 1, 1),
		"order": [
			{"speaker": "Drifter", "text": "Hey. You're the one who cooks around here, right?"},
			{"speaker": "Drifter", "text": "I need something made. Can you cook it for me?", "choices": [
				{"text": "Sure. Give me a few minutes."},
				{"text": "What's in it for me?", "reply": [
					{"speaker": "Drifter", "text": "I'll make it worth your while."},
					{"speaker": "Player", "text": "...Fine. I'll do it."},
				]},
				{"text": "I'm busy. Find someone else.", "reply": [
					{"speaker": "Drifter", "text": "There is no one else. Please."},
					{"speaker": "Player", "text": "...Fine. Give me a few minutes."},
				]},
			]},
			{"speaker": "Drifter", "text": "I'll wait right here."},
		],
		"great": ["...This is perfect. I've never seen it this clean.", "Here. You've earned every cent: $%d."],
		"ok": ["Hm. Not bad. It'll do.", "$%d. Don't spend it all in one place."],
		"bad": ["This is weak. I could have done better myself.", "$%d. Take it or leave it."],
	},
	{
		"name": "Tall Stranger", "scale": 1.15, "tint": Color(0.75, 0.85, 1.0),
		"order": [
			{"speaker": "Tall Stranger", "text": "Quiet out here tonight. Too quiet."},
			{"speaker": "Tall Stranger", "text": "They say your product is the best in the county. Prove it.", "choices": [
				{"text": "Coming right up.", "reply": [
					{"speaker": "Tall Stranger", "text": "Good. I don't like waiting."},
				]},
				{"text": "Who's they?", "reply": [
					{"speaker": "Tall Stranger", "text": "People who'd rather not be named. Just cook."},
				]},
				{"text": "I don't serve strangers.", "reply": [
					{"speaker": "Tall Stranger", "text": "Then we're not strangers for long. Name's not important."},
					{"speaker": "Player", "text": "...Give me a few minutes."},
				]},
			]},
			{"speaker": "Tall Stranger", "text": "I'll be right here."},
		],
		"great": ["Remarkable. The rumours undersold you.", "$%d. Expect to see me again."],
		"ok": ["Acceptable.", "$%d. I've had better, I've had worse."],
		"bad": ["Hmph. The rumours were exaggerated.", "$%d. Consider it a lesson."],
	},
	{
		"name": "Nervous Kid", "scale": 0.82, "tint": Color(1.0, 0.8, 0.8),
		"order": [
			{"speaker": "Nervous Kid", "text": "Is this... is this the place? Sorry, I've never done this before."},
			{"speaker": "Nervous Kid", "text": "My friend said you could help me out. Could you? Please?", "choices": [
				{"text": "Relax. I've got you.", "reply": [
					{"speaker": "Nervous Kid", "text": "Thank you, thank you. I'll stay out of the way."},
				]},
				{"text": "How old are you?", "reply": [
					{"speaker": "Nervous Kid", "text": "Old enough! ...Mostly. Please don't make this weird."},
					{"speaker": "Player", "text": "...Give me a few minutes."},
				]},
				{"text": "Money first.", "reply": [
					{"speaker": "Nervous Kid", "text": "I-I'll pay when it's done, I swear!"},
				]},
			]},
			{"speaker": "Nervous Kid", "text": "I'll just... stand here. Not looking at anything."},
		],
		"great": ["Wow! It's so... clean? I think? Is that good?", "Here, take it, it's all I have: $%d."],
		"ok": ["Oh. Okay. I guess that's fine.", "$%d. Is that enough?"],
		"bad": ["Um. That doesn't look right. My friend said it'd look different.", "$%d. Sorry, sorry."],
	},
	{
		"name": "Old Timer", "scale": 0.93, "tint": Color(0.9, 0.85, 0.65),
		"order": [
			{"speaker": "Old Timer", "text": "Evening, son. Haven't seen a rig like this since '98."},
			{"speaker": "Old Timer", "text": "I've got a taste for something special. You think you can handle it?", "choices": [
				{"text": "I can handle it.", "reply": [
					{"speaker": "Old Timer", "text": "Ha! Confidence. I like that."},
				]},
				{"text": "Tell me about '98.", "reply": [
					{"speaker": "Old Timer", "text": "Nope. Some stories stay in the desert."},
					{"speaker": "Player", "text": "...Fair enough. Give me a few minutes."},
				]},
				{"text": "You look like trouble.", "reply": [
					{"speaker": "Old Timer", "text": "Trouble's my middle name. Pay's good though."},
				]},
			]},
			{"speaker": "Old Timer", "text": "Take your time. At my age, I've got plenty."},
		],
		"great": ["Well I'll be. That's the real thing.", "Here you go, son: $%d. Keep the change, there isn't any."],
		"ok": ["Not bad. Not what we made back in the day, but not bad.", "$%d. Buy yourself a hat."],
		"bad": ["Bah. Kids these days.", "$%d. Learn your craft."],
	},
	{
		"name": "Suit", "scale": 1.05, "tint": Color(0.65, 0.65, 0.75),
		"order": [
			{"speaker": "Suit", "text": "Let's keep this professional. I'm on a schedule."},
			{"speaker": "Suit", "text": "One order, standard spec. Can you deliver?", "choices": [
				{"text": "Standard spec. No problem.", "reply": [
					{"speaker": "Suit", "text": "Efficient. Good."},
				]},
				{"text": "Who do you work for?", "reply": [
					{"speaker": "Suit", "text": "A firm. That's all you need to know."},
					{"speaker": "Player", "text": "...Give me a few minutes."},
				]},
				{"text": "My prices just went up.", "reply": [
					{"speaker": "Suit", "text": "Noted. Your product had better justify it."},
				]},
			]},
			{"speaker": "Suit", "text": "I'll be waiting. Don't take long."},
		],
		"great": ["Flawless. I'll be recommending you upstairs.", "$%d. Pleasure doing business."],
		"ok": ["Within tolerance.", "$%d. Receipts are not necessary."],
		"bad": ["Below spec. I'll have to discount this.", "$%d. Do better."],
	},
	{
		"name": "Wanderer", "scale": 0.9, "tint": Color(0.75, 1.0, 0.8),
		"order": [
			{"speaker": "Wanderer", "text": "The stars are weird tonight. Did you notice?"},
			{"speaker": "Wanderer", "text": "Anyway. I walked a long way for this. You got something for me?", "choices": [
				{"text": "I can cook something up.", "reply": [
					{"speaker": "Wanderer", "text": "Beautiful. I'll count the stars while I wait."},
				]},
				{"text": "The stars look normal to me.", "reply": [
					{"speaker": "Wanderer", "text": "That's what they want you to think."},
					{"speaker": "Player", "text": "...Give me a few minutes."},
				]},
				{"text": "How far did you walk?", "reply": [
					{"speaker": "Wanderer", "text": "Far enough that my shoes filed a complaint."},
				]},
			]},
			{"speaker": "Wanderer", "text": "No rush. The desert's patient."},
		],
		"great": ["It sparkles like a clear sky. Thank you.", "$%d. Found it in the dunes, honest."],
		"ok": ["Mm. Does the job.", "$%d. The desert provides."],
		"bad": ["The stars wouldn't approve of this.", "$%d. Maybe it'll grow on me."],
	},
]

signal arrived
signal order_taken
signal served

enum Phase { IDLE, ORDER, HANDOFF }

@export var rv_path: NodePath = ^"../RV"
@export var window_path: NodePath = ^"../VanWindow"
@export var texture: Texture2D
@export var height := 0.75 # world units; the window's top edge is ~0.8 above the sand
@export var start_delay := 0.0
@export var start_distance := 1.2 # how far out from the wall it starts
@export var start_side_offset := 6.0 # how far along the van it starts, left or right
@export var walk_speed := 0.45
@export var stop_distance := 0.1 # gap left between the sprite and the glass
@export var next_customer_delay := 4.0 # seconds after one leaves before the next walks up

var sprite: Sprite3D
var from: Vector3
var to: Vector3
var travelled := 0.0
var length := 0.0
var walking := false
var van_window: Node
var dialogue_box: CanvasLayer
var waiting_for_window := false
var phase := Phase.IDLE
var out_dir: Vector3
var window_pos: Vector3
var deck: Array = [] # shuffled customer profiles; reshuffled once everyone has had a turn
var customer: Dictionary

func _ready() -> void:
	var rv: Node3D = get_node(rv_path)
	van_window = get_node(window_path)
	# Same window geometry as desert.gd: wall plane x = 79, window centred at z = -107
	var out := (rv.global_transform.basis.orthonormalized() * Vector3.RIGHT)
	out.y = 0.0
	out = out.normalized()
	var window := rv.global_transform * Vector3(79, 0, -107)
	window.y = 0.0
	out_dir = out
	window_pos = window
	_pick_start()

	sprite = Sprite3D.new()
	sprite.texture = texture if texture else _placeholder_texture()
	_pick_customer()
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

	add_to_group("window_enemy")
	dialogue_box = DIALOGUE_SCENE.instantiate()
	add_child(dialogue_box)
	dialogue_box.finished.connect(_on_dialogue_finished)
	# The player is added after this node, so find it once the scene is ready
	get_tree().process_frame.connect(_connect_player, CONNECT_ONE_SHOT)
	van_window.fully_opened.connect(_on_window_opened)

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	sprite.visible = true
	walking = true

# Draws the next customer from the shuffled deck and restyles the sprite to match
func _pick_customer() -> void:
	if deck.is_empty():
		deck = CUSTOMERS.duplicate()
		deck.shuffle()
		# Don't repeat the previous customer back to back across reshuffles
		if not customer.is_empty() and deck.size() > 1 and deck.back() == customer:
			deck.reverse()
	customer = deck.pop_back()
	sprite.pixel_size = height * customer["scale"] / sprite.texture.get_height()
	sprite.modulate = customer["tint"]

# Comes in from the left or right end of the van
func _pick_start() -> void:
	var side := out_dir.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
	to = window_pos + out_dir * stop_distance
	from = window_pos + out_dir * start_distance + side * start_side_offset
	length = from.distance_to(to)

# The served customer is gone: a new one walks up from the end of the van
func _next_customer() -> void:
	sprite.visible = false
	sprite.position.y = 0.0
	await get_tree().create_timer(next_customer_delay).timeout
	_pick_customer()
	_pick_start()
	travelled = 0.0
	global_position = from
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

func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.dish_served.connect(_on_dish_served)

func _on_window_opened() -> void:
	if waiting_for_window:
		_start_dialogue()

func _start_dialogue() -> void:
	waiting_for_window = false
	Gamestate.order_prompt = ""
	phase = Phase.ORDER
	dialogue_box.start(customer["order"])

func _on_dialogue_finished() -> void:
	match phase:
		Phase.ORDER:
			phase = Phase.IDLE
			order_taken.emit()
		Phase.HANDOFF:
			phase = Phase.IDLE
			Gamestate.money += Gamestate.last_payout
			served.emit()
			_next_customer()

# The customer reacts to the batch's purity, then pays
func _on_dish_served() -> void:
	phase = Phase.HANDOFF
	var purity: float = Gamestate.last_purity
	var grade := "great" if purity >= 0.85 else ("ok" if purity >= 0.6 else "bad")
	var reaction: Array = customer[grade]
	var who: String = customer["name"]
	var lines: Array = [{"speaker": "Player", "text": "Here you go. Fresh." if grade == "great" else "Here you go."}]
	for i in reaction.size():
		var text: String = reaction[i]
		if "%d" in text:
			text = text % Gamestate.last_payout
		lines.append({"speaker": who, "text": text})
	dialogue_box.start(lines)

# Placeholder: a dark hunched silhouette with pale eyes
func _placeholder_texture() -> Texture2D:
	var w := 48
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body := Color(0.2, 0.2, 0.24) # light enough for the per-customer tint to show
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
