extends Node
class_name TestCaveOpening

const CAVE_SCENE: PackedScene = preload("res://scenes/cave.tscn")
const CAVE_MUSIC: AudioStream = preload("res://assets/sounds/cave1.mp3")

func test_cave_opening_routes_to_boss_gate_and_all_levers() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(cave)
	await get_tree().process_frame
	var sequence: CaveIntroSequence = cave as CaveIntroSequence
	assert(sequence != null)
	assert(sequence.ROUTE == [
		NodePath("bossfight/evilwizard"),
		NodePath("rooms_gates/endgate"),
		NodePath("interactables/lever"),
		NodePath("interactables/lever2"),
		NodePath("interactables/lever3"),
	])
	assert(sequence.OPENING_ZOOM == Vector2(6.6, 6.6))
	var player: PlayerController = cave.get_node("knight") as PlayerController
	var camera: Camera2D = player.get_node("Camera2D") as Camera2D
	assert(camera.zoom == Vector2(6.6, 6.6))
	assert(not player.teleport_locked)
	var pause_menu: PauseMenu = cave.get_node("PauseLayer/PauseMenu") as PauseMenu
	assert(pause_menu.skip_startup_sequence)
	cave.queue_free()
	await get_tree().process_frame

func test_cave_music_callback_is_bound_to_first_resume_frame() -> void:
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
