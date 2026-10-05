extends Node
class_name TestWorldOpeningCutscene

const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"

func test_world_scene_wires_the_opening_dialogue() -> void:
	var world_scene: PackedScene = load(WORLD_SCENE_PATH) as PackedScene
	var world: WorldOpeningCutscene = world_scene.instantiate() as WorldOpeningCutscene
	assert(world != null, "world root should use the opening cutscene script")
	assert(world.get_node_or_null("knight") != null)
	assert(world.get_cutscene_dialogue().size() == 13)
	assert(world.get_cutscene_dialogue()[0] == "Princess: “You’ll be here?”")
	assert(world.get_cutscene_dialogue()[12] == "Knight: “…I promised.”")
	assert(ResourceLoader.exists("res://scenes/portal.tscn"))
	world.free()

func test_portal_arrival_position_is_above_the_player_feet() -> void:
	var cutscene: WorldOpeningCutscene = WorldOpeningCutscene.new()
	cutscene.original_player_position = Vector2(100.0, 200.0)
	var portal_position: Vector2 = cutscene.call("_get_portal_spawn_position")
	assert(portal_position == Vector2(100.0, 152.0), "arrival portal should spawn 48 px above the player's feet")
	cutscene.free()

func test_all_opening_cutscene_sound_assets_exist() -> void:
	var paths: Array[String] = [
		"res://assets/sounds/ceilingfan.mp3",
		"res://assets/sounds/dooropen.mp3",
		"res://assets/sounds/running.mp3",
		"res://assets/sounds/stretcherwheels.mp3",
		"res://assets/sounds/scuffle.mp3",
		"res://assets/sounds/portalenter.mp3",
		"res://assets/sounds/portalexit.mp3",
	]
	for sound_path: String in paths:
		assert(ResourceLoader.exists(sound_path), "missing opening cutscene sound: %s" % sound_path)
	assert(WorldOpeningCutscene.FOOTSTEPS_SOUND_PATH == "res://assets/sounds/running.mp3", "cutscene should keep using the original footsteps sound")

func test_opening_sfx_cues_are_stopped_and_separated_before_the_next_cue() -> void:
	var cutscene: WorldOpeningCutscene = WorldOpeningCutscene.new()
	add_child(cutscene)
	await cutscene._play_optional_sound_with_gap(WorldOpeningCutscene.DOOR_SOUND_PATH, -4.0, 0.05)
	assert(cutscene.active_audio.size() == 1)
	assert(not is_instance_valid(cutscene.active_audio[0]), "finished cue should be freed before the next sound can start")
	assert(WorldOpeningCutscene.SFX_SILENCE_GAP >= 0.4, "sound cues should have a clear silent gap")
	cutscene.queue_free()
	await get_tree().process_frame

func test_button_presses_progress_opening_dialogue() -> void:
	var cutscene: WorldOpeningCutscene = WorldOpeningCutscene.new()
	add_child(cutscene)
	cutscene.dialogue_ui = load("res://scenes/npcdialogueui.tscn").instantiate() as NpcDialogueUI
	cutscene.add_child(cutscene.dialogue_ui)
	cutscene.opening_sequence_active = true
	cutscene.waiting_for_dialogue = true
	cutscene.dialogue_ui.show_dialogue("A short line")
	var press: InputEventKey = InputEventKey.new()
	press.pressed = true
	press.keycode = KEY_SPACE
	cutscene._input(press)
	assert(not cutscene.dialogue_ui.typing, "first press should reveal the full line")
	cutscene._input(press)
	assert(cutscene.dialogue_advance_requested, "next press should advance dialogue")
	cutscene.queue_free()
	await get_tree().process_frame

func test_portal_scene_has_looping_animated_sprite() -> void:
	var portal_scene: PackedScene = load("res://scenes/portal.tscn") as PackedScene
	var portal: Node2D = portal_scene.instantiate() as Node2D
	add_child(portal)
	var sprite: AnimatedSprite2D = portal.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert(sprite.sprite_frames.has_animation(&"default"))
	assert(sprite.sprite_frames.get_frame_count(&"default") == 8)
	assert(sprite.sprite_frames.get_animation_loop(&"default"))
	portal.queue_free()
	await get_tree().process_frame
