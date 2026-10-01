extends Node
class_name TestMidworldNpcIntro

const MIDWORLD_SCENE: PackedScene = preload("res://scenes/midworld.tscn")


func test_midworld_has_npc_intro_setup() -> void:
	var midworld: Node2D = MIDWORLD_SCENE.instantiate() as Node2D
	add_child(midworld)
	await get_tree().process_frame
	var npc: Area2D = midworld.get_node("NPC1") as Area2D
	var level_end: LevelEnd = midworld.get_node("levelend") as LevelEnd
	var player: PlayerController = midworld.get_node("knight") as PlayerController
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
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
	midworld.queue_free()
	await get_tree().process_frame
