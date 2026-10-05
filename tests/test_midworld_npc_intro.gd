extends Node
class_name TestMidworldNpcIntro

const MIDWORLD_SCENE: PackedScene = preload("res://scenes/midworld.tscn")

func _add_test_floor(parent: Node2D, center_x: float, top_y: float) -> void:
	var floor: StaticBody2D = StaticBody2D.new()
	floor.collision_layer = 64
	floor.position = Vector2(center_x, top_y + 4.0)
	parent.add_child(floor)
	var floor_shape: CollisionShape2D = CollisionShape2D.new()
	var floor_rectangle: RectangleShape2D = RectangleShape2D.new()
	floor_rectangle.size = Vector2(400.0, 8.0)
	floor_shape.shape = floor_rectangle
	floor.add_child(floor_shape)

func test_midworld_intro_lands_airborne_player_before_dialogue_freezes_them() -> void:
	var midworld: Node2D = MIDWORLD_SCENE.instantiate() as Node2D
	add_child(midworld)
	await get_tree().process_frame
	var player: PlayerController = midworld.get_node("knight") as PlayerController
	var npc: Area2D = midworld.get_node("NPC1") as Area2D
	var dialogue_ui: NpcDialogueUI = midworld.get_node("NpcDialogueUI") as NpcDialogueUI
	var dialogue_box: TextureRect = dialogue_ui.get_node("Root/DialogueBox") as TextureRect
	player.intro_run_active = false
	player.exit_run_active = false
	player.elevator_ride_active = false
	player.collision_mask = 64
	player.state = PlayerController.PlayerState.LOCOMOTION
	player.velocity = Vector2.ZERO
	get_tree().root.set_meta(MidworldNpcIntro.INTRO_SEEN_META, true)
	_add_test_floor(midworld, 1500.0, 720.0)
	player.global_position = Vector2(1500.0, 200.0)
	await get_tree().physics_frame
	assert(not player.is_on_floor(), "test setup must place the player in the air")
	get_tree().root.remove_meta(MidworldNpcIntro.INTRO_SEEN_META)
	midworld.call("start_npc_intro")
	assert(player.cinematic_fall_active)
	assert(not player.teleport_locked, "the player must keep falling before the cutscene freezes them")
	assert(not dialogue_box.visible, "dialogue should wait until the player reaches the floor")
	for _frame: int in range(120):
		if player.teleport_locked:
			break
		await get_tree().physics_frame
	assert(player.is_on_floor(), "the player should land before the dialogue cutscene locks them; position=%s velocity=%s active=%s locked=%s" % [player.global_position, player.velocity, player.cinematic_fall_active, player.teleport_locked])
	assert(player.teleport_locked)
	await get_tree().create_timer(0.75).timeout
	assert(dialogue_box.visible)
	get_tree().root.remove_meta(MidworldNpcIntro.INTRO_SEEN_META)
	midworld.queue_free()
	await get_tree().process_frame

func test_midworld_has_npc_intro_setup() -> void:
	if get_tree().root.has_meta(MidworldNpcIntro.INTRO_SEEN_META):
		get_tree().root.remove_meta(MidworldNpcIntro.INTRO_SEEN_META)
	var midworld: Node2D = MIDWORLD_SCENE.instantiate() as Node2D
	add_child(midworld)
	await get_tree().process_frame
	var npc: Area2D = midworld.get_node("NPC1") as Area2D
	var level_end: LevelEnd = midworld.get_node("levelend") as LevelEnd
	var player: PlayerController = midworld.get_node("knight") as PlayerController
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	player.intro_run_active = false
	player.exit_run_active = false
	player.elevator_ride_active = false
	player.collision_mask = 64
	player.state = PlayerController.PlayerState.LOCOMOTION
	player.velocity = Vector2.ZERO
	_add_test_floor(midworld, 158.0, 100.0)
	player.global_position = Vector2(158.0, 60.0)
	for _frame: int in range(24):
		await get_tree().physics_frame
	assert(player.is_on_floor(), "test setup should settle the player on the floor")
	assert(midworld.has_method("start_npc_intro"))
	assert(npc.collision_layer == 0)
	assert(npc.collision_mask == 2)
	assert(level_end != null)
	assert(level_end.collision_layer == 0)
	assert(level_end.collision_mask == 2)
	assert(level_end.next_scene == "res://scenes/cave.tscn")
	assert(sprite.sprite_frames.has_animation(&"shrug"))
	var dialogue_ui: NpcDialogueUI = midworld.get_node("NpcDialogueUI") as NpcDialogueUI
	var dialogue_box: TextureRect = dialogue_ui.get_node("Root/DialogueBox") as TextureRect
	var reward_panel: TextureRect = dialogue_ui.get_node("Root/RewardPanel") as TextureRect
	var dialogue_label: Label = dialogue_ui.get_node("Root/DialogueBox/DialogueLabel") as Label
	var reward_title: Label = dialogue_ui.get_node("Root/RewardPanel/RewardTitle") as Label
	var charger: TextureRect = dialogue_ui.get_node("Root/RewardPanel/Mp3Charger") as TextureRect
	assert(dialogue_box.size.x >= 900.0)
	assert(dialogue_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	assert(reward_panel.anchor_left == 0.0 and reward_panel.anchor_right == 1.0)
	assert(reward_panel.size.y >= 240.0)
	assert(reward_title.text == "You got a...")
	assert(charger.size == Vector2(480.0, 480.0))
	assert(is_equal_approx(charger.position.y + charger.size.y * 0.5, reward_panel.size.y * 0.5 - 16.0))
	midworld.call("start_npc_intro")
	assert(sprite.animation == &"idle")
	await get_tree().create_timer(0.75).timeout
	var cinematic_camera: Camera2D = midworld.get_node("NpcCinematicCamera") as Camera2D
	assert(cinematic_camera.global_position.is_equal_approx(npc.global_position + Vector2(0.0, 14.0)))
	assert(dialogue_box.visible)
	var intro_camera_y: float = cinematic_camera.global_position.y
	midworld.call("_pan_to_player_stage")
	await get_tree().create_timer(0.75).timeout
	assert(is_equal_approx(cinematic_camera.global_position.y, intro_camera_y))
	get_tree().root.remove_meta(MidworldNpcIntro.INTRO_SEEN_META)
	midworld.queue_free()
	await get_tree().process_frame
