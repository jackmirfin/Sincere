extends Node
class_name TestCaveOpening

const CAVE_SCENE: PackedScene = preload("res://scenes/cave.tscn")
const CAVE_MUSIC: AudioStream = preload("res://assets/sounds/cave1.mp3")

func test_cave_layers_use_twilight_parallax_depths() -> void:
	var cave: CaveIntroSequence = CAVE_SCENE.instantiate() as CaveIntroSequence
	cave.sequence_finished = true
	add_child(cave)
	await get_tree().process_frame
	var background_parallax: Parallax2D = cave.get_node("BackgroundParallax") as Parallax2D
	var light_parallax: Parallax2D = cave.get_node("lightparallax") as Parallax2D
	var background: TileMapLayer = background_parallax.get_node("background") as TileMapLayer
	var light: TileMapLayer = light_parallax.get_node("light") as TileMapLayer
	var platforms: TileMapLayer = cave.get_node("platforms") as TileMapLayer
	assert(background != null and light != null)
	assert(is_equal_approx(background_parallax.scroll_scale.x, 0.92))
	assert(is_equal_approx(background_parallax.scroll_scale.y, 0.92))
	assert(is_equal_approx(light_parallax.scroll_scale.x, 0.96))
	assert(is_equal_approx(light_parallax.scroll_scale.y, 0.96))
	assert(platforms.get_parent() == cave, "Collidable platforms should remain fixed in world space")
	assert(light_parallax.scroll_scale.x > background_parallax.scroll_scale.x)
	assert(light_parallax.scroll_scale.x < 1.0)
	cave.queue_free()
	await get_tree().process_frame

func test_cave_opening_routes_to_all_levers_and_boss() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(cave)
	await get_tree().process_frame
	var sequence: CaveIntroSequence = cave as CaveIntroSequence
	assert(sequence != null)
	assert(sequence.ROUTE == [
		NodePath("interactables/lever"),
		NodePath("interactables/lever2"),
		NodePath("interactables/lever3"),
		NodePath("bossfight/evilwizard"),
	])
	assert(sequence.STOP_DURATION == 0.3)
	assert(sequence.BOSS_DIALOGUE.size() == 9)
	assert(sequence.BOSS_DIALOGUE[0]["text"] == "How fares she?")
	assert(sequence.BOSS_DIALOGUE[7]["text"] == "He is already here.")
	for line: Dictionary in sequence.BOSS_DIALOGUE:
		assert(not str(line["text"]) in ["You said the first course might be enough.", "It was not.", "It will weaken her.", "Yes.", "Will it save her?", "It may give her a chance."])
	assert(sequence.OPENING_ZOOM == Vector2(6.6, 6.6))
	assert(sequence.BOSS_CAMERA_OFFSET == Vector2(10.0, 0.0))
	assert(sequence.KING_EXIT_DURATION == 3.8)
	var chest1: Node2D = cave.get_node("interactables/chest") as Node2D
	var chest2: Node2D = cave.get_node("interactables/chest2") as Node2D
	var chest3: Node2D = cave.get_node("interactables/chest3") as Node2D
	assert(chest1.position == Vector2(2743.0, 530.0))
	assert(chest2.position == Vector2(2843.0, 530.0))
	assert(chest3.position == Vector2(2943.0, 530.0))
	var player: PlayerController = cave.get_node("knight") as PlayerController
	var camera: Camera2D = player.get_node("Camera2D") as Camera2D
	assert(camera.zoom == Vector2(6.6, 6.6))
	assert(camera.limit_left == 0)
	assert(camera.limit_top == 0)
	assert(camera.limit_right == 5088)
	assert(camera.limit_bottom == 736)
	assert(not player.teleport_locked)
	await get_tree().create_timer(0.6).timeout
	assert(sequence.player_dropped)
	assert(is_instance_valid(sequence.cinematic_camera))
	assert(sequence.cinematic_camera.limit_left == 0)
	assert(sequence.cinematic_camera.limit_top == 0)
	assert(sequence.cinematic_camera.limit_right == 5088)
	assert(sequence.cinematic_camera.limit_bottom == 736)
	var pause_menu: PauseMenu = cave.get_node("PauseLayer/PauseMenu") as PauseMenu
	assert(pause_menu.skip_startup_sequence)
	cave.queue_free()
	await get_tree().process_frame

func test_pause_frame_three_reframes_cinematic_camera_to_player() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var sequence: CaveIntroSequence = cave as CaveIntroSequence
	sequence.sequence_finished = true
	add_child(cave)
	await get_tree().process_frame
	var player: PlayerController = cave.get_node("knight") as PlayerController
	player.set_teleport_locked(true)
	var player_camera: Camera2D = player.get_node("Camera2D") as Camera2D
	var camera: Camera2D = Camera2D.new()
	sequence.cinematic_camera = camera
	sequence.add_child(camera)
	camera.global_position = player.global_position + Vector2(180.0, -40.0)
	camera.zoom = sequence.OPENING_TRAVEL_ZOOM
	sequence.pause_started = true
	player.animated_sprite.play(&"pause")
	player.animated_sprite.set_frame_and_progress(sequence.PAUSE_FOCUS_FRAME, 0.0)
	await get_tree().create_timer(0.5).timeout
	assert(camera.global_position.distance_to(player.global_position + player_camera.position) < 1.0)
	assert(camera.zoom == sequence.OPENING_ZOOM)
	cave.queue_free()
	await get_tree().process_frame

func test_music_callback_starts_music_on_first_resume_frame() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(cave)
	await get_tree().process_frame
	var player: PlayerController = cave.get_node("knight") as PlayerController
	var music: AudioStreamPlayer = cave.get_node("BackgroundMusic") as AudioStreamPlayer
	var opening: CaveIntroSequence = cave as CaveIntroSequence
	music.stop()
	opening.call("_start_resume")
	player.animated_sprite.set_frame_and_progress(1, 0.0)
	assert(music.playing)
	assert(music.stream == CAVE_MUSIC)
	cave.queue_free()
	await get_tree().process_frame


func test_boss_stays_visible_until_the_camera_has_left_him() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var sequence: CaveIntroSequence = cave as CaveIntroSequence
	sequence.sequence_finished = true
	add_child(cave)
	await get_tree().process_frame
	var wizard: CaveEvilWizard = cave.get_node("bossfight/evilwizard") as CaveEvilWizard
	var camera: Camera2D = Camera2D.new()
	sequence.add_child(camera)
	sequence.cinematic_camera = camera
	camera.zoom = sequence.OPENING_TRAVEL_ZOOM
	camera.global_position = wizard.global_position
	camera.make_current()
	wizard.activate_for_intro()
	await get_tree().process_frame
	assert(sequence.call("_wizard_is_visible_in_camera", wizard))
	camera.global_position = Vector2(635.0, 439.0)
	await get_tree().process_frame
	assert(not sequence.call("_wizard_is_visible_in_camera", wizard))
	assert(wizard.visible)
	cave.queue_free()
	await get_tree().process_frame


func test_wizard_waits_for_the_king_instead_of_walking_in() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var sequence: CaveIntroSequence = cave as CaveIntroSequence
	sequence.sequence_finished = true
	add_child(cave)
	await get_tree().process_frame
	var wizard: CaveEvilWizard = cave.get_node("bossfight/evilwizard") as CaveEvilWizard
	var original_position: Vector2 = wizard.global_position
	await sequence._prepare_boss_entrance(wizard)
	assert(wizard.global_position == original_position)
	assert(wizard.visible)
	assert(sequence.king.global_position == original_position + Vector2(sequence.KING_STAGE_X_OFFSET, sequence.KING_STAGE_Y_OFFSET))
	var king_sprite: AnimatedSprite2D = sequence.king.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert(king_sprite.animation == &"idle")
	assert(sequence.call("_camera_target_position", wizard) == original_position + sequence.BOSS_CAMERA_OFFSET)
	cave.queue_free()
	await get_tree().process_frame


func test_dialogue_advances_only_from_a_button_press() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var sequence: CaveIntroSequence = cave as CaveIntroSequence
	sequence.sequence_finished = true
	add_child(cave)
	await get_tree().process_frame
	sequence.dialogue_active = true
	sequence.dialogue_ui.characters_per_second = 1.0
	sequence.dialogue_ui.show_dialogue("How fares she?")
	assert(not sequence.dialogue_advance_requested)
	await get_tree().create_timer(0.9).timeout
	assert(not sequence.dialogue_advance_requested)
	assert(sequence.dialogue_ui.full_text == "How fares she?")
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_SPACE
	press.pressed = true
	sequence._unhandled_input(press)
	assert(not sequence.dialogue_ui.typing)
	assert(not sequence.dialogue_advance_requested)
	sequence._unhandled_input(press)
	assert(sequence.dialogue_advance_requested)
	cave.queue_free()
	await get_tree().process_frame


func test_dialogue_boxes_switch_sides_with_the_speaker() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var sequence: CaveIntroSequence = cave as CaveIntroSequence
	sequence.sequence_finished = true
	add_child(cave)
	await get_tree().process_frame
	sequence.call("_set_dialogue_side", "KING")
	assert(sequence.dialogue_ui.dialogue_box.anchor_left == 1.0)
	assert(sequence.dialogue_ui.dialogue_box.offset_left == -560.0)
	assert(sequence.dialogue_ui.dialogue_box.offset_right == -20.0)
	assert(sequence.dialogue_ui.dialogue_box.offset_top == -250.0)
	assert(sequence.dialogue_ui.dialogue_box.offset_bottom == -30.0)
	assert(sequence.dialogue_ui.dialogue_box.offset_right - sequence.dialogue_ui.dialogue_box.offset_left == 540.0)
	sequence.call("_set_dialogue_side", "WIZARD")
	assert(sequence.dialogue_ui.dialogue_box.anchor_left == 0.0)
	assert(sequence.dialogue_ui.dialogue_box.offset_left == 20.0)
	assert(sequence.dialogue_ui.dialogue_box.offset_right == 560.0)
	cave.queue_free()
	await get_tree().process_frame


func test_endgate_closes_after_the_king_leaves() -> void:
	var gate_scene: PackedScene = load("res://scenes/gate.tscn") as PackedScene
	var gate: CaveGate = gate_scene.instantiate() as CaveGate
	add_child(gate)
	gate.open_gate()
	if not gate.opened:
		await gate.opened_signal
	assert(gate.opened)
	gate.close_gate()
	if gate.closing:
		await gate.closed_signal
	assert(not gate.opened)
	assert(not gate.closing)
	assert(gate.visible)
	assert(gate.animated_sprite.animation == &"shut")
	assert(gate.collision_layer == 1)
	gate.queue_free()
	await get_tree().process_frame
