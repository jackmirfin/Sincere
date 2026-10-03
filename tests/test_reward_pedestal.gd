extends Node
class_name TestRewardPedestal

const PEDESTAL_SCENE: PackedScene = preload("res://scenes/rewardspedestal.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const CLAIMED_META: StringName = &"twilight_reward_items_claimed"
const EXPECTED_ITEMS: Array[StringName] = [&"dualdaggers", &"firecharm", &"shield"]

func test_pedestal_offers_unique_items_and_only_claims_one() -> void:
	get_tree().root.set_meta(CLAIMED_META, [])
	var pedestal: RewardPedestal = PEDESTAL_SCENE.instantiate() as RewardPedestal
	add_child(pedestal)
	await get_tree().process_frame
	assert(pedestal.slot_items.size() == 3)
	var offered_ids: Array[StringName] = pedestal.slot_items.duplicate()
	offered_ids.sort()
	var expected_ids: Array[StringName] = EXPECTED_ITEMS.duplicate()
	expected_ids.sort()
	assert(offered_ids == expected_ids, "pedestal should offer every pool item once in shuffled slots")
	for slot: Area2D in pedestal.reward_slots:
		assert(slot.collision_mask == 2 and slot.monitoring, "%s has mask %d and monitoring=%s" % [slot.name, slot.collision_mask, str(slot.monitoring)])
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	player.set_physics_process(false)
	player.position = Vector2(400.0, 400.0)
	add_child(player)
	await get_tree().process_frame
	var selected_id: StringName = pedestal.slot_items[1]
	var selected_texture: Texture2D = pedestal.slot_icons[1].texture
	pedestal.reward_slots[1].body_entered.emit(player)
	pedestal._handle_reward_interaction(false)
	assert(pedestal.selected_slot_index == -1, "entering a slot should not claim it without E")
	assert(not get_tree().root.get_meta(CLAIMED_META).has(selected_id))
	assert(pedestal.interact_prompt.visible, "show the E prompt while the player is near a reward")
	assert(not player.teleport_locked)
	pedestal._handle_reward_interaction(true)
	assert(pedestal.selected_slot_index == 1 and pedestal.selected_item_id == selected_id)
	assert(pedestal.animation == &"middle", "middle slot must play the middle pedestal animation")
	assert(pedestal.slot_icons[1].visible)
	assert(not pedestal.slot_icons[0].visible and not pedestal.slot_icons[2].visible)
	assert(not pedestal.interact_prompt.visible)
	assert(player.teleport_locked, "freeze the player while the selected reward is presented")
	assert(get_tree().root.get_meta(CLAIMED_META).has(selected_id))
	pedestal._select_reward(0, player)
	assert(pedestal.selected_slot_index == 1, "a second reward should not be claimable")
	await get_tree().create_timer(0.55).timeout
	assert(pedestal.dialogue_ui.reward_panel.visible)
	assert(pedestal.dialogue_ui.reward_icon.texture == selected_texture)
	assert(pedestal.dialogue_ui.reward_title.text == "You got: %s" % pedestal._get_reward_definition(selected_id)["display_name"])
	var advance_event: InputEventAction = InputEventAction.new()
	advance_event.action = &"interact"
	advance_event.pressed = true
	pedestal._unhandled_input(advance_event)
	assert(not pedestal.dialogue_ui.reward_panel.visible)
	assert(not player.teleport_locked)
	pedestal.queue_free()
	player.queue_free()
	await get_tree().process_frame
	var next_pedestal: RewardPedestal = PEDESTAL_SCENE.instantiate() as RewardPedestal
	add_child(next_pedestal)
	await get_tree().process_frame
	assert(not next_pedestal.slot_items.has(selected_id), "a previously claimed item should not be offered again")
	assert(next_pedestal.slot_items.count(&"") == 1, "leave the claimed item's slot empty rather than repeat an item")
	next_pedestal.queue_free()
	get_tree().root.set_meta(CLAIMED_META, [])
	await get_tree().process_frame

func test_each_slot_selects_its_matching_pedestal_animation() -> void:
	var expected_animations: Array[StringName] = [&"left", &"middle", &"right"]
	for slot_index: int in range(expected_animations.size()):
		get_tree().root.set_meta(CLAIMED_META, [])
		var pedestal: RewardPedestal = PEDESTAL_SCENE.instantiate() as RewardPedestal
		add_child(pedestal)
		var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
		player.auto_start = false
		player.set_physics_process(false)
		player.position = Vector2(400.0, 400.0)
		add_child(player)
		await get_tree().process_frame
		pedestal.reward_slots[slot_index].body_entered.emit(player)
		pedestal._handle_reward_interaction(true)
		assert(pedestal.animation == expected_animations[slot_index], "slot %d expected %s; got %s" % [slot_index, expected_animations[slot_index], pedestal.animation])
		pedestal.queue_free()
		player.queue_free()
		await get_tree().process_frame
	get_tree().root.set_meta(CLAIMED_META, [])
