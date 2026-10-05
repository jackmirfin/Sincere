extends Node
class_name TestStartScreen

const START_SCREEN_SCENE: PackedScene = preload("res://scenes/start_screen.tscn")

func test_start_screen_uses_background_and_places_start_button_on_right() -> void:
	var screen: StartScreen = START_SCREEN_SCENE.instantiate() as StartScreen
	add_child(screen)
	await get_tree().process_frame
	var background: TextureRect = screen.get_node("Background") as TextureRect
	var start_button: Button = screen.get_node("StartButton") as Button
	assert(background.texture.resource_path == "res://assets/ui/startscreen.png")
	assert(background.anchor_right == 1.0 and background.anchor_bottom == 1.0)
	assert(start_button.text == "START")
	assert(start_button.anchor_left > 0.5, "start button should be positioned on the right side")
	assert(start_button.pressed.is_connected(screen._on_start_pressed), "start button should be wired to the game transition")
	assert(StartScreen.GAME_SCENE_PATH == "res://scenes/world.tscn", "Start should load World 1 directly")
	screen.queue_free()
	await get_tree().process_frame

func test_start_screen_is_the_project_launch_scene() -> void:
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/start_screen.tscn")
