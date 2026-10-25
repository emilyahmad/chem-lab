extends Node3D
# Temporary screenshot harness (delete after use)
const VIEWS := [
	[Vector3(-0.62, 0.46, 0.35), Vector3(-0.2, 0.22, 0.05)],
	[Vector3(-0.62, 0.42, -0.1), Vector3(-0.25, 0.22, -0.75)],
	[Vector3(1.0, 0.25, 0.0), Vector3(5.0, 0.0, 1.0)],
	[Vector3(1.0, 0.25, 0.0), Vector3(5.0, 0.0, 1.0)],
	[Vector3(1.6, 0.22, 0.2), Vector3(2.0, 0.12, 0.2)],
]
func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(get_tree().quit)
	Gamestate.skip_van_intro = true
	var main = load("res://Scenes/Gameplay/main.tscn").instantiate()
	var t0 := Time.get_ticks_msec()
	add_child(main)
	print("main ready ms: ", Time.get_ticks_msec() - t0)
	main.get_node("Player").hide()
	main.get_node("HUD").visible = false
	var desert = main.get_node("Environment/Desert")
	var tw: Dictionary = desert._make_tumbleweed(0.15)
	tw.root.global_position = Vector3(2.0, 0.13, 0.2)
	var cam := Camera3D.new()
	cam.fov = 70
	cam.near = 0.01
	add_child(cam)
	for i in 30: await get_tree().process_frame
	var out := OS.get_cmdline_user_args()[0]
	print("grass instances: ", main.get_node("Environment/Grass").multimesh.instance_count)
	for i in VIEWS.size():
		cam.global_position = VIEWS[i][0]
		cam.look_at(VIEWS[i][1])
		cam.make_current()
		for f in (60 if i == 3 else 8): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/view%d.png" % [out, i])
	get_tree().quit()
