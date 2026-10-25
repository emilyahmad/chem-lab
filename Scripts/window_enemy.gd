extends Node3D
# A figure that shambles in from the desert and stops right outside the van's
# side window. It's one character picked out of the low-poly people pack, on
# render layer 2 (like the desert scenery) so only the moonlight touches it.

const DESERT_LAYER := 2

const DIALOGUE_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")
const PEOPLE_SCENE = preload("res://Assets/Models/low_poly_people/scene.gltf")
const CAUGHT_SCREEN = preload("res://Scripts/caught_screen.gd")

# Each customer has their own look (character model, height multiplier and walking speed multiplier), order
# dialogue with its own choices, and a reaction for each grade of dish.
# "%d" in a reaction line is replaced with the payout.
const CUSTOMERS := [
	{
		"name": "Drifter", "model": "casual_Female_K_", "speed": 0.95, "scale": 1.0,
		"order": [
			{"speaker": "Drifter", "text": "Saw your light from the highway. Figured nobody parks out here by accident."},
			{"speaker": "Drifter", "text": "I'm told you cook the good stuff. I've got a long road ahead and a short supply of luck.", "choices": [
				{"text": "Sure. Give me a few minutes."},
				{"text": "What's in it for me?", "reply": [
					{"speaker": "Drifter", "text": "Cash, and a favour from a man who never forgets one."},
					{"speaker": "Player", "text": "Fine. I'll do it."},
				]},
				{"text": "I'm busy. Find someone else.", "reply": [
					{"speaker": "Drifter", "text": "I've driven past a hundred towns to get here. You're it."},
					{"speaker": "Player", "text": "Fine. Give me a few minutes."},
				]},
			]},
			{"speaker": "Drifter", "text": "Take your time. I've got nowhere better to be."},
		],
		"great": ["Well, that's the cleanest thing I've seen since the Carolinas.", "$%d. Worth every dollar."],
		"ok": ["It'll get me down the road.", "$%d. Don't spend it all in one place."],
		"bad": ["Rough. Real rough. I've had better from a gas station.", "$%d. Take it or leave it."],
	},
	{
		"name": "Tall Stranger", "model": "casual_Male_G", "speed": 1.15, "scale": 1.15,
		"order": [
			{"speaker": "Tall Stranger", "text": "Funny thing about the desert. Sound carries, and so do rumours."},
			{"speaker": "Tall Stranger", "text": "The rumour says your product is the best in the county. I'd like to check.", "choices": [
				{"text": "Coming right up.", "reply": [
					{"speaker": "Tall Stranger", "text": "Good. I'm a patient man, but only up to a point."},
				]},
				{"text": "Who's been talking?", "reply": [
					{"speaker": "Tall Stranger", "text": "People who like their names unspoken. Cook."},
				]},
				{"text": "I don't serve strangers.", "reply": [
					{"speaker": "Tall Stranger", "text": "Then consider us introduced. Now we're acquaintances."},
					{"speaker": "Player", "text": "Give me a few minutes."},
				]},
			]},
			{"speaker": "Tall Stranger", "text": "I'll be right here, enjoying the view."},
		],
		"great": ["Remarkable. For once, the rumours undersold it.", "$%d. You'll be seeing me again."],
		"ok": ["Adequate. I've had better, I've had worse.", "$%d. Don't let it go to your head."],
		"bad": ["A pity. The rumours were generous.", "$%d. Consider it tuition."],
	},
	{
		"name": "Nervous Kid", "model": "little_boy_B", "speed": 1.5, "scale": 0.82, "floss": true,
		"order": [
			{"speaker": "Nervous Kid", "text": "Hi! Sorry! Is this the place? I've never done this before, I read about it, I mean, a friend told me."},
			{"speaker": "Nervous Kid", "text": "He said you were the best and also not scary. Are you not scary?", "choices": [
				{"text": "Relax. I've got you."},
				{"text": "How old are you?", "reply": [
					{"speaker": "Nervous Kid", "text": "Twenty-one! Almost! Please don't make this weird."},
					{"speaker": "Player", "text": "Give me a few minutes."},
				]},
				{"text": "Money first.", "reply": [
					{"speaker": "Nervous Kid", "text": "I'll pay when it's done, I swear! I even brought exact change!"},
				]},
			]},
			{"speaker": "Nervous Kid", "text": "I'll just stand here. Admiring the sand. Not looking at anything."},
		],
		"great": ["Wow! It's so shiny! Is it supposed to be shiny? It's great, right?", "Here, it's everything I have: $%d."],
		"ok": ["Oh, okay! That seems fine. I think. It's fine, right?", "$%d. Is that enough? Sorry."],
		"bad": ["Um, it's a bit cloudy. My friend's wasn't cloudy.", "$%d. Sorry, sorry, thank you!"],
	},
	{
		"name": "Old Timer", "model": "elder_Female_A", "speed": 0.55, "scale": 0.93,
		"order": [
			{"speaker": "Old Timer", "text": "Evening, dear. That's a fine old rig. Reminds me of a summer I'm not allowed to talk about."},
			{"speaker": "Old Timer", "text": "I've got a taste for something special, and a few good years left to enjoy it.", "choices": [
				{"text": "I can handle it.", "reply": [
					{"speaker": "Old Timer", "text": "Ha! Spoken like someone who hasn't burned a batch yet."},
				]},
				{"text": "Tell me about that summer.", "reply": [
					{"speaker": "Old Timer", "text": "Some stories stay buried in the sand, dear. That's what it's for."},
					{"speaker": "Player", "text": "Fair enough. Give me a few minutes."},
				]},
				{"text": "You look like trouble.", "reply": [
					{"speaker": "Old Timer", "text": "Sweetheart, I invented trouble. The pay's good, though."},
				]},
			]},
			{"speaker": "Old Timer", "text": "Take all the time you need. I've got plenty of it."},
		],
		"great": ["Well, I'll be. That's the real thing, clear as a desert morning.", "Here you go: $%d. Keep the change. There isn't any."],
		"ok": ["Not what we made back in the day, but it'll do the job.", "$%d. Buy yourself a hat."],
		"bad": ["Bah. Kids these days want it fast and get it wrong.", "$%d. Go practise."],
	},
	{
		"name": "Doctor", "model": "Doctor_Male_B", "speed": 1.3, "scale": 1.05,
		"order": [
			{"speaker": "Doctor", "text": "I've got a patient waiting two towns over, so let's be efficient."},
			{"speaker": "Doctor", "text": "One order, standard dose, no surprises. Can you deliver?", "choices": [
				{"text": "Standard dose. No problem.", "reply": [
					{"speaker": "Doctor", "text": "Efficient. I like efficient. It's good bedside manner."},
				]},
				{"text": "Which clinic are you from?", "reply": [
					{"speaker": "Doctor", "text": "A clinic with a very long name and a very short memory."},
					{"speaker": "Player", "text": "Give me a few minutes."},
				]},
				{"text": "My prices just went up.", "reply": [
					{"speaker": "Doctor", "text": "Noted. Your product had better justify the markup."},
				]},
			]},
			{"speaker": "Doctor", "text": "I'll be checking my pager. Don't take it personally."},
		],
		"great": ["Flawless. Cleaner than anything in my supply cabinet.", "$%d. A pleasure doing business."],
		"ok": ["Within clinical tolerance.", "$%d. No receipt necessary."],
		"bad": ["Below spec. I wouldn't prescribe this to anyone.", "$%d. Do better next time."],
	},
	{
		"name": "Wanderer", "model": "casual_Female_G", "speed": 0.8, "scale": 0.9,
		"order": [
			{"speaker": "Wanderer", "text": "The stars are rearranged tonight. Did you notice, or is it just me?"},
			{"speaker": "Wanderer", "text": "Anyway, I walked a very long way for this. Tell me you've got something.", "choices": [
				{"text": "I can cook something up.", "reply": [
					{"speaker": "Wanderer", "text": "Lovely. I'll count the stars while I wait. Again."},
				]},
				{"text": "The stars look normal to me.", "reply": [
					{"speaker": "Wanderer", "text": "That's what they want you to think. Very clever of them."},
					{"speaker": "Player", "text": "Give me a few minutes."},
				]},
				{"text": "How far did you walk?", "reply": [
					{"speaker": "Wanderer", "text": "Far enough that my shoes filed a complaint."},
				]},
			]},
			{"speaker": "Wanderer", "text": "No rush. The desert's in no hurry, and neither am I."},
		],
		"great": ["It sparkles like a clear night sky. Thank you.", "$%d. I found it in the dunes, honest."],
		"ok": ["Mm, it does the job. The desert approves, mostly.", "$%d. The sand provides."],
		"bad": ["The stars wouldn't approve of this one.", "$%d. Maybe it'll grow on me."],
	},
	{
		"name": "Officer", "model": "police_Female_A", "speed": 1.0, "cop": true, "scale": 1.1,
		"order": [
			{"speaker": "Officer", "text": "Evening! Lovely night for a walk. Just a regular citizen, taking a walk, in the middle of nowhere."},
			{"speaker": "Officer", "text": "So I heard you could whip me up a little something. Strictly off the record.", "choices": [
				{"text": "Sure. Give me a few minutes."},
				{"text": "Nice badge you've got there.", "reply": [
					{"speaker": "Officer", "text": "What badge? That's a, uh, belt buckle. Anyway, can you help me or not?"},
					{"speaker": "Player", "text": "Give me a few minutes."},
				]},
			]},
			{"speaker": "Officer", "text": "I'll wait right here, totally normally."},
		],
		"busted": ["Thank you. That's all the evidence I need.", "You're under arrest."],
	},
	{
		"name": "Detective", "model": "casual_Male_K", "speed": 0.95, "cop": true, "scale": 1.0,
		"order": [
			{"speaker": "Detective", "text": "Great rig! Very cosy. Do you get many visitors out here?"},
			{"speaker": "Detective", "text": "I'm new in town, and somebody said you're the person to see about a little pick-me-up.", "choices": [
				{"text": "Coming right up.", "reply": [
					{"speaker": "Detective", "text": "Wonderful. I'll keep my hands where you can see them."},
				]},
				{"text": "You ask a lot of questions.", "reply": [
					{"speaker": "Detective", "text": "Occupational habit. Asking questions is the whole job."},
					{"speaker": "Player", "text": "Give me a few minutes."},
				]},
			]},
			{"speaker": "Detective", "text": "Take your time. I'm just here to look around."},
		],
		"busted": ["Gotcha. Every word of that is on tape.", "You're under arrest."],
	},
]

# Walk cycle: peak swing angles in degrees, applied to the skeleton by hand
# because the pack only ships one non-walking animation
const THIGH_SWING := 25.0
const KNEE_BEND := 50.0
const ARM_SWING := 25.0
const ELBOW_BEND := 20.0

# Idle emotes: now and then a customer standing around does one of these
const EMOTES := ["wave", "scratch", "look", "nod", "shrug"]
const EMOTE_TIME := 2.2 # seconds per emote
const EMOTE_GAP := Vector2(3.0, 8.0) # standing time between emotes (min, max)
const FLOSS_FADE := 0.25 # seconds to ease the idle floss in or out around an emote

const LEAVE_ANGLE := 75.0 # degrees either side of straight out from the van that they may wander off
const LEAVE_DISTANCE := Vector2(5.0, 8.0)
const REACTIONS := {"great": "dance", "ok": "shrug", "bad": "rage"}

const SLAMMED_RAGE_TIME := 1.4 # seconds a customer fumes after the window is shut on them

const DIVE_TIME := 0.55 # seconds the cop is airborne, from the window to the player's face
const DIVE_ARC := 0.18 # how high the dive bows above a straight line
const ARREST_HOLD_TIME := 0.7 # seconds the screen shakes with the cop on top of the player before it fades out
const REFUSE_HINT := "   [E] Close the window to turn them away"

signal arrived
signal order_taken
signal served
signal left

enum Phase { IDLE, ORDER, HANDOFF }

@export var rv_path: NodePath = ^"../RV"
@export var window_path: NodePath = ^"../VanWindow"
@export var height := 0.64 # world units; the window's top edge is ~0.8 above the sand
@export var start_delay := 0.0
@export var first_customer_delay := 3.0 # seconds after the intro ends before the first customer appears
@export var lane_distance := Vector2(0.9, 1.6) # how far out from the wall the walk along the van runs (min, max)
@export var start_side_offset := Vector2(4.0, 8.0) # how far along the van it starts, left or right (min, max)
@export var stop_side_offset := 0.2 # how far either side of the window's centre it may stop
@export var walk_speed := 0.9
@export var stop_distance := Vector2(0.1, 0.35) # gap left between the sprite and the glass (min, max)
@export var start_with_cop := false # testing: the first customer is a cop
@export var next_customer_delay := 4.0 # seconds after one leaves before the next walks up

var sprite: Node3D # holds the current customer's model
var models: Dictionary = {} # character name -> the nodes that make up that character
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
var customer: Dictionary
var rig: Dictionary # current model's skeleton, bone indices and swing axis (see _build_rig)
var base_facing: Vector3 # which way the current model faces before any turning
var feet_offset: Vector3 # model-space point that sits at the node's origin
var model_scale := 1.0
var turn_tween: Tween
var walk_dir: Vector3 # heading of the current leg of the walk
var face_dir: Vector3 # the way the model is actually facing, turning towards walk_dir
var corner: Vector3 # where the walk along the van turns towards the window
var leg_length := 0.0
var emote := ""
var emote_time := 0.0
var emote_wait := 2.0
var floss_blend := 0.0 # 0..1, how far into the idle floss a "floss" customer is
var floss_time := 0.0
var reaction := "" # emote held while the customer reacts to their order
var leaving := false
var leave_dir: Vector3
var leave_distance := 0.0
var leave_travelled := 0.0
var cuffs: Node3D # the arresting cop's handcuffs, hung off their hand
var cuffs_scale := 1.0

func _ready() -> void:
	var rv: Node3D = get_node(rv_path)
	van_window = get_node(window_path)
	# Same window geometry as desert.gd: wall plane x = 79, window centred at z = -107
	var out := (rv.global_transform.basis.orthonormalized() * Vector3.RIGHT)
	out.y = 0.0
	out = out.normalized()
	var window := rv.global_transform * Vector3(79, 0, -107)
	window.y = 0.0
	# The sash slides open over the -z half of the pane, so stand in the middle of
	# that opening (the window's left quarter) rather than the window's centre
	var along := (rv.global_transform.basis.orthonormalized() * Vector3.BACK)
	along.y = 0.0
	window += along.normalized() * (-van_window.width / 4.0)
	out_dir = out
	window_pos = window
	_pick_start()

	sprite = Node3D.new()
	sprite.visible = false
	add_child(sprite)
	_build_models()
	_pick_customer()
	global_position = from

	add_to_group("window_enemy")
	dialogue_box = DIALOGUE_SCENE.instantiate()
	add_child(dialogue_box)
	dialogue_box.finished.connect(_on_dialogue_finished)
	# The player is added after this node, so find it once the scene is ready
	get_tree().process_frame.connect(_connect_player, CONNECT_ONE_SHOT)
	van_window.fully_opened.connect(_on_window_opened)
	van_window.closed.connect(_on_window_closed)

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	# The intro (round 1-3) sets the round once the scene is ready; hold the first customer
	# until the player has control, then leave them a moment to look around the lab
	await get_tree().process_frame
	if Gamestate.round >= 1 and Gamestate.round <= 3:
		while Gamestate.round < 4:
			await get_tree().process_frame
		await get_tree().create_timer(first_customer_delay).timeout
	sprite.visible = true
	walking = true

# Draws the next customer from the shuffled deck and restyles the sprite to match
func _pick_customer() -> void:
	var deck: Array = Gamestate.customer_deck
	if deck.is_empty():
		for c in CUSTOMERS:
			deck.append(c["name"])
		deck.shuffle()
		# Don't repeat the previous customer back to back across reshuffles
		if deck.size() > 1 and deck.back() == Gamestate.last_customer:
			deck.push_front(deck.pop_back())
	if start_with_cop and customer.is_empty():
		start_with_cop = false
		for i in deck.size():
			if _profile(deck[i]).get("cop", false):
				deck.push_back(deck.pop_at(i))
				break
	customer = _profile(deck.pop_back())
	Gamestate.last_customer = customer["name"]
	_show_model(customer["model"])
	Gamestate.roll_dose_palette() # every customer gets their own dosing colours

func _profile(customer_name: String) -> Dictionary:
	for c in CUSTOMERS:
		if c["name"] == customer_name:
			return c
	return CUSTOMERS[0]

# Comes in from the left or right end of the van, walks along it, then turns
# towards the window. Each customer gets their own lane, stopping spot and start.
func _pick_start() -> void:
	var side_dir := out_dir.cross(Vector3.UP).normalized()
	var stop_gap := randf_range(stop_distance.x, stop_distance.y)
	var lane := maxf(randf_range(lane_distance.x, lane_distance.y), stop_gap + 0.4)
	var stop_side := randf_range(-stop_side_offset, stop_side_offset)
	var start_side := randf_range(start_side_offset.x, start_side_offset.y) * (1.0 if randf() < 0.5 else -1.0)
	to = window_pos + out_dir * stop_gap + side_dir * stop_side
	corner = window_pos + out_dir * lane + side_dir * stop_side
	from = window_pos + out_dir * lane + side_dir * start_side
	leg_length = from.distance_to(corner)
	length = leg_length + corner.distance_to(to)
	walk_dir = (corner - from)
	walk_dir.y = 0.0
	walk_dir = walk_dir.normalized()
	face_dir = walk_dir

# The served customer is gone: a new one walks up from the end of the van
func _next_customer() -> void:
	await _walk_away()
	sprite.visible = false
	sprite.position.y = 0.0
	await get_tree().create_timer(next_customer_delay).timeout
	_pick_start()
	_pick_customer()
	travelled = 0.0
	global_position = from
	sprite.visible = true
	walking = true

# Heads off in a random direction away from the van, then is gone
func _walk_away() -> void:
	if turn_tween:
		turn_tween.kill()
	reaction = ""
	emote = ""
	_stand()
	sprite.position.y = 0.0
	face_dir = -out_dir
	leave_dir = out_dir.rotated(Vector3.UP, deg_to_rad(randf_range(-LEAVE_ANGLE, LEAVE_ANGLE)))
	leave_distance = randf_range(LEAVE_DISTANCE.x, LEAVE_DISTANCE.y)
	leave_travelled = 0.0
	leaving = true
	await left

func _process(delta: float) -> void:
	if cuffs:
		# Skeleton and model scales don't apply to the cuffs: world-sized, dangling below the hand
		var attach := cuffs.get_parent() as Node3D
		cuffs.global_basis = Basis(Vector3.UP, sin(Time.get_ticks_msec() * 0.012) * 0.4).scaled(Vector3.ONE * cuffs_scale)
		cuffs.global_position = attach.global_position + Vector3(0, -0.035 * cuffs_scale, 0)
	if leaving:
		var step: float = walk_speed * customer.get("speed", 1.0) * delta
		leave_travelled += step
		global_position += leave_dir * step
		face_dir = face_dir.slerp(leave_dir, minf(delta * 6.0, 1.0))
		_orient(face_dir)
		var leave_cycle: float = leave_travelled / (height * customer["scale"] * 1.1) * TAU
		_pose_walk(leave_cycle)
		sprite.position.y = absf(cos(leave_cycle)) * 0.012
		if leave_travelled >= leave_distance:
			leaving = false
			left.emit()
		return
	if not walking:
		_update_emote(delta)
		return
	travelled = minf(travelled + walk_speed * customer.get("speed", 1.0) * delta, length)
	if travelled < leg_length:
		global_position = from.lerp(corner, travelled / leg_length)
		walk_dir = (corner - from).normalized()
	else:
		global_position = corner.lerp(to, (travelled - leg_length) / (length - leg_length))
		walk_dir = (to - corner).normalized()
	# Swing round at the corner instead of snapping
	face_dir = face_dir.slerp(walk_dir, minf(delta * 8.0, 1.0))
	_orient(face_dir)
	# One full stride (two steps) is a little longer than the body is tall, so the planted foot doesn't skate
	var cycle: float = travelled / (height * customer["scale"] * 1.1) * TAU
	_pose_walk(cycle)
	sprite.position.y = absf(cos(cycle)) * 0.012
	if travelled >= length:
		walking = false
		floss_blend = 0.0
		sprite.position.y = 0.0
		_stand()
		_turn_to_window()
		_on_arrived()

# Swings round from the way they were walking to face the van
func _turn_to_window() -> void:
	var from_dir := face_dir
	if turn_tween:
		turn_tween.kill()
	turn_tween = create_tween()
	turn_tween.tween_method(func(t: float): _orient(from_dir.slerp(-out_dir, t)), 0.0, 1.0, 0.5)

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
	dialogue_box.extra_hint = REFUSE_HINT
	dialogue_box.start(customer["order"])

# Shutting the window on a customer who hasn't had their order taken turns them away
func _on_window_closed() -> void:
	if phase != Phase.ORDER:
		return
	dialogue_box.cancel()
	dialogue_box.extra_hint = ""
	phase = Phase.IDLE
	Gamestate.alert_requested.emit("You shut the window on the %s." % customer["name"])
	reaction = "rage"
	await get_tree().create_timer(SLAMMED_RAGE_TIME).timeout
	_next_customer()

func _on_dialogue_finished() -> void:
	dialogue_box.extra_hint = ""
	match phase:
		Phase.ORDER:
			phase = Phase.IDLE
			order_taken.emit()
		Phase.HANDOFF:
			phase = Phase.IDLE
			if customer.get("cop", false):
				_arrest()
				return
			Gamestate.money += Gamestate.last_payout
			Gamestate.total_earned += Gamestate.last_payout
			Gamestate.best_payout = maxi(Gamestate.best_payout, Gamestate.last_payout)
			Gamestate.best_purity = maxf(Gamestate.best_purity, Gamestate.last_purity)
			Gamestate.purities.append(Gamestate.last_purity)
			served.emit()
			_next_customer()

# Serving a cop ends the run: they charge through the glass and cuff the player
func _arrest() -> void:
	var player := get_tree().get_first_node_in_group("player")
	Gamestate.timer_running = false
	Gamestate.order_prompt = ""
	Gamestate.cooking_prompt = ""
	if player:
		player.controls_locked = true
	if turn_tween:
		turn_tween.kill()
	reaction = ""
	emote = ""
	emote_wait = 1.0e9 # no idle emotes while charging
	_stand()
	face_dir = -out_dir
	_orient(face_dir)
	_make_cuffs()

	# Crouch for a beat, then launch through the glass at the player's face
	await get_tree().create_timer(0.4).timeout
	await _dive(player)
	CAUGHT_SCREEN.impact_effects(get_tree(), player.get_node_or_null("PlayerCamera") if player else null)
	await get_tree().create_timer(ARREST_HOLD_TIME).timeout

	# Fade to black, then the verdict
	CAUGHT_SCREEN.end_run(get_tree(), "You were caught.")

# Superman dive: body flat in the air, legs straight out behind, arms stretched
# ahead with the wrists crossed and the cuffs open, flying through the window into the camera
func _dive(player: Node) -> void:
	var cam: Camera3D = player.get_node_or_null("PlayerCamera") if player else null
	var start := global_position
	var target := cam.global_position + Vector3(0, -0.05, 0) if cam else window_pos - out_dir + Vector3(0, 0.4, 0)
	var glass := Vector3(window_pos.x, start.y, window_pos.z)
	var travel := (target - start).dot(-out_dir)
	var dive := {
		"start": start, "target": target, "hip": height * customer["scale"] * 0.5, "shattered": false,
		"glass_t": clampf((glass - start).dot(-out_dir) / maxf(travel, 0.01), 0.0, 1.0), "cam": cam,
	}
	cuffs_scale = 2.5
	var tw := create_tween()
	tw.tween_method(_dive_step.bind(dive), 0.0, 1.0, DIVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	sprite.transform = Transform3D.IDENTITY

func _dive_centre(u: float, dive: Dictionary) -> Vector3:
	var start: Vector3 = dive["start"]
	var target: Vector3 = dive["target"]
	var hip: float = dive["hip"]
	return start.lerp(target, u) + Vector3(0, hip * (1.0 - u) + sin(u * PI) * DIVE_ARC, 0)

func _dive_step(t: float, dive: Dictionary) -> void:
	var start: Vector3 = dive["start"]
	var hip: float = dive["hip"]
	var here := _dive_centre(t, dive)
	var heading := _dive_centre(minf(t + 0.02, 1.0), dive) - here
	heading = heading.normalized() if heading.length() > 0.0001 else -out_dir
	# Head leads along the flight path, belly towards the ground
	var basis := Basis(Quaternion(Vector3.UP, heading))
	global_position = Vector3(here.x, start.y, here.z)
	sprite.transform = Transform3D(basis, Vector3(0, here.y - start.y, 0) - basis * Vector3(0, hip, 0))
	_pose_dive(t)
	if not dive["shattered"] and t >= dive["glass_t"]:
		dive["shattered"] = true
		van_window.shatter()
		CAUGHT_SCREEN.impact_effects(get_tree(), dive["cam"])

func _pose_dive(t: float) -> void:
	if rig.is_empty():
		return
	var front: Vector3 = rig["front"]
	var side: Vector3 = rig["side"]
	var r: Dictionary = rig["raise"]
	var fwd: float = rig["forward"]
	var env := smoothstep(0.0, 0.25, t)
	_stand()
	# Straight arms thrown overhead and past vertical so the wrists cross
	_rot("R UpperArm", front, r["R UpperArm"] * deg_to_rad(188.0) * env)
	_rot("L UpperArm", front, -r["R UpperArm"] * deg_to_rad(188.0) * env)
	# Legs straight and together, trailing slightly behind the hips
	_swing("L Thigh", -fwd * deg_to_rad(8.0) * env)
	_swing("R Thigh", -fwd * deg_to_rad(8.0) * env)
	_rot("Head", side, deg_to_rad(-25.0) * env)

# Handcuffs from primitives (the pack has none), hung off the right hand and
# kept upright in the world so they dangle whatever way the wrist turns
func _make_cuffs() -> void:
	if rig.is_empty():
		return
	var skel: Skeleton3D = rig["skel"]
	var attach := BoneAttachment3D.new()
	attach.bone_name = skel.get_bone_name(rig["bones"]["R Hand"])
	skel.add_child(attach)
	cuffs = Node3D.new()
	attach.add_child(cuffs)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.82, 0.85)
	mat.metallic = 0.6
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.37, 0.4)
	for x in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.012
		torus.outer_radius = 0.022
		torus.material = mat
		ring.mesh = torus
		ring.position = Vector3(x * 0.035, -0.01, 0)
		ring.rotation_degrees = Vector3(0, 0, 90)
		cuffs.add_child(ring)
	var chain := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.003
	rod.bottom_radius = 0.003
	rod.height = 0.05
	rod.material = mat
	chain.mesh = rod
	chain.rotation_degrees = Vector3(0, 0, 90)
	chain.position = Vector3(0, -0.01, 0)
	cuffs.add_child(chain)
	for mi in cuffs.find_children("*", "VisualInstance3D", true, false):
		mi.layers = DESERT_LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# The customer reacts to the batch's purity, then pays
func _on_dish_served() -> void:
	phase = Phase.HANDOFF
	var purity: float = Gamestate.last_purity
	var is_cop: bool = customer.get("cop", false)
	var grade := "great" if purity >= 0.85 else ("ok" if purity >= 0.6 else "bad")
	if is_cop:
		grade = "busted"
	var reply_lines: Array = customer[grade]
	var who: String = customer["name"]
	var lines: Array = [{"speaker": "Player", "text": "Here you go. Fresh." if grade == "great" else "Here you go."}]
	for i in reply_lines.size():
		var text: String = reply_lines[i]
		if "%d" in text:
			text = text % Gamestate.last_payout
		lines.append({"speaker": who, "text": text})
	dialogue_box.start(lines)
	reaction = REACTIONS.get(grade, "")

# The pack holds every character side by side in one scene. Sort its nodes
# into per-character groups (a body, its rig, then any hair/glasses props that
# follow) so each customer can show just their own.
func _build_models() -> void:
	var pack: Node3D = PEOPLE_SCENE.instantiate()
	sprite.add_child(pack)
	var root := pack.find_child("RootNode", true, false)
	var current := ""
	for child in root.get_children():
		var n := String(child.name)
		if not (n.begins_with("rig_") or n.begins_with("acc_") or n.begins_with("hair") or n.begins_with("stetho")):
			current = n
			models[current] = []
		models[current].append(child)
	for child in pack.find_children("*", "VisualInstance3D", true, false):
		child.layers = DESERT_LAYER
		if child is GeometryInstance3D:
			child.extra_cull_margin = 16384.0 # skinned meshes' culling boxes are unreliable
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# Shows one character, scaled to this customer's height with their feet at the
# node's origin and centred on it
func _show_model(key: String) -> void:
	for k in models:
		for node in models[k]:
			node.visible = (k == key)
	var pack := sprite.get_child(0) as Node3D
	pack.transform = Transform3D.IDENTITY
	var box := _visible_bounds(models[key], pack)
	model_scale = height * customer["scale"] / box.size.y
	feet_offset = Vector3(box.get_center().x, box.position.y, box.get_center().z)
	base_facing = _facing(models[key], pack)
	_build_rig(models[key], pack)
	emote = ""
	reaction = ""
	floss_blend = 0.0
	emote_wait = randf_range(EMOTE_GAP.x, EMOTE_GAP.y)
	_orient(walk_dir)

# Turns the model about its feet so it faces `dir` (world, flat)
func _orient(dir: Vector3) -> void:
	var pack := sprite.get_child(0) as Node3D
	var basis := Basis(Vector3.UP, base_facing.signed_angle_to(dir, Vector3.UP)).scaled(Vector3.ONE * model_scale)
	pack.transform = Transform3D(basis, -(basis * feet_offset))

# Finds the bones that swing during a walk, and the axis they swing about
# (the model's left-right line, as seen from the skeleton)
func _build_rig(nodes: Array, pack: Node3D) -> void:
	rig = {}
	for node in nodes:
		var skels: Array = node.find_children("*", "Skeleton3D", true, false)
		if skels.is_empty():
			continue
		var skel: Skeleton3D = skels[0]
		var bones := {}
		for key in ["L Thigh", "R Thigh", "L Calf", "R Calf", "L UpperArm", "R UpperArm", "L Forearm", "R Forearm", "L Clavicle", "R Clavicle", "R Hand", "Head"]:
			for i in skel.get_bone_count():
				if String(skel.get_bone_name(i)).begins_with("bip " + key):
					bones[key] = i
					break
		if bones.size() < 12:
			return
		var to_pack := pack.global_transform.affine_inverse().basis * skel.global_transform.basis
		var side: Vector3 = to_pack * (skel.get_bone_global_rest(bones["L Thigh"]).origin - skel.get_bone_global_rest(bones["R Thigh"]).origin)
		side.y = 0.0
		side = side.normalized()
		# Which way of turning about the axis swings a hanging limb forward
		var forward := 1.0 if (Quaternion(side, 0.1) * Vector3.DOWN).dot(base_facing) > 0.0 else -1.0
		rig = {"skel": skel, "bones": bones, "axis": (to_pack.orthonormalized().inverse() * side).normalized(), "forward": forward,
				"to_skel": to_pack.orthonormalized().inverse(), "side": side, "front": base_facing, "raise": {}}
		rig["to_pack"] = to_pack.orthonormalized()
		_pick_raise_signs()
		return

# Poses the legs and arms for a point in the walk cycle (phase in radians)
func _pose_walk(phase_angle: float) -> void:
	if rig.is_empty():
		return
	var swing := sin(phase_angle)
	var fwd: float = rig["forward"]
	var t := deg_to_rad(THIGH_SWING)
	var k := deg_to_rad(KNEE_BEND)
	var a := deg_to_rad(ARM_SWING)
	var e := deg_to_rad(ELBOW_BEND)
	# The leg moving forward bends its knee to clear the ground; arms oppose the legs
	_swing("L Thigh", fwd * t * swing)
	_swing("R Thigh", -fwd * t * swing)
	_swing("L Calf", -fwd * k * maxf(0.0, cos(phase_angle)))
	_swing("R Calf", -fwd * k * maxf(0.0, -cos(phase_angle)))
	_swing("L UpperArm", -fwd * a * swing)
	_swing("R UpperArm", fwd * a * swing)
	_swing("L Forearm", fwd * e * (1.0 + maxf(0.0, swing)))
	_swing("R Forearm", fwd * e * (1.0 + maxf(0.0, -swing)))

func _swing(bone: String, angle: float) -> void:
	var skel: Skeleton3D = rig["skel"]
	var i: int = rig["bones"][bone]
	var axis: Vector3 = rig["axis"]
	# Rotate about the left-right axis as seen from the bone's own rest frame
	var local_axis := skel.get_bone_global_rest(i).basis.orthonormalized().inverse() * axis
	skel.set_bone_pose_rotation(i, skel.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion(local_axis.normalized(), angle))

# The rest poses differ (some rigs hold their hands out in front), so rather than
# guess which way lifts a limb, try both ways about the front-back axis and keep
# whichever one actually raises the hand / shoulder
func _pick_raise_signs() -> void:
	var front: Vector3 = rig["front"]
	var best := -INF
	for upper in [1.0, -1.0]:
		for fore in [1.0, -1.0]:
			_stand()
			_rot("R UpperArm", front, upper * deg_to_rad(55.0))
			_rot("R Forearm", front, fore * deg_to_rad(90.0))
			var y := _bone_y("R Hand")
			if y > best:
				best = y
				rig["raise"]["R UpperArm"] = upper
				rig["raise"]["R Forearm"] = fore
	for side in ["L", "R"]:
		var arm: String = side + " UpperArm"
		best = -INF
		for dir in [1.0, -1.0]:
			_stand()
			_rot(side + " Clavicle", front, dir * deg_to_rad(14.0))
			var y := _bone_y(arm)
			if y > best:
				best = y
				rig["raise"][side + " Clavicle"] = dir
	_stand()

func _bone_y(bone: String) -> float:
	var skel: Skeleton3D = rig["skel"]
	return (rig["to_pack"] * skel.get_bone_global_pose(rig["bones"][bone]).origin).y

# Rotates a bone by `angle` about an axis given in the model's own space,
# on top of whatever pose it already has (so call _stand() first each frame)
func _rot(bone: String, axis: Vector3, angle: float) -> void:
	var skel: Skeleton3D = rig["skel"]
	var i: int = rig["bones"][bone]
	var local_axis: Vector3 = skel.get_bone_global_rest(i).basis.orthonormalized().inverse() * (rig["to_skel"] * axis)
	skel.set_bone_pose_rotation(i, skel.get_bone_pose_rotation(i) * Quaternion(local_axis.normalized(), angle))

# Starts a random emote once the customer has been standing around a while
func _update_emote(delta: float) -> void:
	if rig.is_empty() or not sprite.visible:
		return
	if reaction != "":
		if emote != reaction:
			emote = reaction
			emote_time = 0.0
	elif emote == "":
		emote_wait -= delta
		var floss: bool = customer.get("floss", false)
		if emote_wait > 0.0:
			if floss:
				_idle_floss(delta, 1.0)
			return
		# Ease out of the floss before the next emote takes over
		if floss and floss_blend > 0.0:
			_idle_floss(delta, 0.0)
			return
		emote = EMOTES.pick_random()
		emote_time = 0.0
	emote_time += delta
	var t := emote_time / EMOTE_TIME
	if t >= 1.0 and reaction == "":
		emote = ""
		emote_wait = randf_range(EMOTE_GAP.x, EMOTE_GAP.y)
		_stand()
		sprite.position.y = 0.0
		return
	# Ease in and out so the pose never snaps (a held reaction only eases in)
	var env := smoothstep(0.0, 0.2, t) * (1.0 if reaction != "" else smoothstep(1.0, 0.8, t))
	var front: Vector3 = rig["front"]
	var side: Vector3 = rig["side"]
	var r: Dictionary = rig["raise"]
	_stand()
	sprite.position.y = 0.0
	match emote:
		"wave":
			_rot("R UpperArm", front, r["R UpperArm"] * deg_to_rad(90.0) * env)
			_rot("R Forearm", front, r["R Forearm"] * deg_to_rad(45.0 + 25.0 * sin(emote_time * 12.0)) * env)
			_rot("Head", Vector3.UP, deg_to_rad(10.0) * env)
		"scratch":
			_rot("R UpperArm", front, r["R UpperArm"] * deg_to_rad(35.0) * env)
			_rot("R Forearm", front, r["R Forearm"] * deg_to_rad(125.0 + 8.0 * sin(emote_time * 14.0)) * env)
			_rot("Head", front, -r["R UpperArm"] * deg_to_rad(8.0) * env)
		"look":
			_rot("Head", Vector3.UP, deg_to_rad(45.0) * sin(t * TAU) * env)
		"nod":
			_rot("Head", side, deg_to_rad(16.0) * sin(emote_time * 9.0) * env)
		"shrug":
			_rot("L Clavicle", front, r["L Clavicle"] * deg_to_rad(14.0) * env)
			_rot("R Clavicle", front, r["R Clavicle"] * deg_to_rad(14.0) * env)
			_rot("Head", front, deg_to_rad(7.0) * env)
		"dance":
			# Arms pumping overhead, hips swaying, bouncing on the spot
			var beat := emote_time * 10.0
			var fwd: float = rig["forward"]
			_rot("R UpperArm", front, r["R UpperArm"] * deg_to_rad(130.0 + 25.0 * sin(beat)) * env)
			_rot("L UpperArm", front, -r["R UpperArm"] * deg_to_rad(130.0 - 25.0 * sin(beat)) * env)
			_rot("R Forearm", front, r["R Forearm"] * deg_to_rad(25.0) * env)
			_rot("L Forearm", front, -r["R Forearm"] * deg_to_rad(25.0) * env)
			_swing("L Thigh", fwd * deg_to_rad(20.0) * sin(beat * 0.5) * env)
			_swing("R Thigh", -fwd * deg_to_rad(20.0) * sin(beat * 0.5) * env)
			_rot("Head", front, deg_to_rad(12.0) * sin(beat * 0.5) * env)
			sprite.position.y = absf(sin(beat * 0.5)) * 0.04 * env
		"arrest":
			# Cuffs held high in triumph, the other fist pumping, head up
			_rot("R UpperArm", front, r["R UpperArm"] * deg_to_rad(140.0 + 8.0 * sin(emote_time * 9.0)) * env)
			_rot("R Forearm", front, r["R Forearm"] * deg_to_rad(15.0) * env)
			_rot("L UpperArm", front, -r["R UpperArm"] * deg_to_rad(70.0) * env)
			_rot("L Forearm", front, -r["R Forearm"] * deg_to_rad(70.0 + 12.0 * sin(emote_time * 9.0)) * env)
			_rot("Head", side, deg_to_rad(-8.0) * env)
		"rage":
			# Fists up and shaking, head jerking, stomping
			_rot("R UpperArm", front, r["R UpperArm"] * deg_to_rad(80.0) * env)
			_rot("L UpperArm", front, -r["R UpperArm"] * deg_to_rad(80.0) * env)
			_rot("R Forearm", front, r["R Forearm"] * deg_to_rad(70.0 + 15.0 * sin(emote_time * 30.0)) * env)
			_rot("L Forearm", front, -r["R Forearm"] * deg_to_rad(70.0 - 15.0 * sin(emote_time * 30.0)) * env)
			_rot("Head", Vector3.UP, deg_to_rad(14.0) * sin(emote_time * 28.0) * env)
			sprite.position.y = maxf(0.0, sin(emote_time * 16.0)) * 0.025 * env

# Idle floss: arms swung across the body one way while the hips go the other
func _idle_floss(delta: float, target: float) -> void:
	floss_blend = move_toward(floss_blend, target, delta / FLOSS_FADE)
	floss_time += delta
	var env := smoothstep(0.0, 1.0, floss_blend)
	var front: Vector3 = rig["front"]
	var side: Vector3 = rig["side"]
	var r: Dictionary = rig["raise"]
	var beat := floss_time * 9.0
	var swing := sin(beat)
	_stand()
	# Both arms the same way (sharing one sign), so they swing together
	_rot("R UpperArm", front, r["R UpperArm"] * deg_to_rad(30.0 * swing + 10.0) * env)
	_rot("L UpperArm", front, r["R UpperArm"] * deg_to_rad(30.0 * swing - 10.0) * env)
	_rot("R Forearm", front, r["R Forearm"] * deg_to_rad(15.0) * env)
	_rot("L Forearm", front, -r["R Forearm"] * deg_to_rad(15.0) * env)
	_rot("R Thigh", front, -r["R UpperArm"] * deg_to_rad(8.0 * swing) * env)
	_rot("L Thigh", front, -r["R UpperArm"] * deg_to_rad(8.0 * swing) * env)
	_rot("Head", front, -r["R UpperArm"] * deg_to_rad(6.0 * swing) * env)
	_rot("Head", side, deg_to_rad(4.0) * env)

func _stand() -> void:
	if not rig.is_empty():
		(rig["skel"] as Skeleton3D).reset_bone_poses()

# Which way the model faces, flattened onto the ground (in pack space): at right
# angles to the line from its right thigh to its left, since the rest pose
# doesn't tell us which way the feet or arms point
func _facing(nodes: Array, pack: Node3D) -> Vector3:
	var to_pack := pack.global_transform.affine_inverse()
	for node in nodes:
		for skel in node.find_children("*", "Skeleton3D", true, false):
			var left := -1
			var right := -1
			for i in skel.get_bone_count():
				var bone_name: String = skel.get_bone_name(i)
				if bone_name.begins_with("bip L Thigh"):
					left = i
				elif bone_name.begins_with("bip R Thigh"):
					right = i
			if left < 0 or right < 0:
				continue
			var side: Vector3 = skel.get_bone_global_rest(left).origin - skel.get_bone_global_rest(right).origin
			side = to_pack.basis * skel.global_transform.basis * side
			side.y = 0.0
			return side.normalized().cross(Vector3.UP)
	return Vector3.FORWARD

# Skinned meshes don't report a usable AABB, so measure the skeleton's bones
func _visible_bounds(nodes: Array, pack: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var to_pack := pack.global_transform.affine_inverse()
	for node in nodes:
		for skel in node.find_children("*", "Skeleton3D", true, false):
			for i in skel.get_bone_count():
				var p: Vector3 = to_pack * (skel.global_transform * skel.get_bone_global_rest(i).origin)
				box = AABB(p, Vector3.ZERO) if first else box.expand(p)
				first = false
	return box
