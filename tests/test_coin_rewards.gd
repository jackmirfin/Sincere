extends Node
class_name TestCoinRewards

const CAVE_SCENE: PackedScene = preload("res://scenes/cave.tscn")


func test_cave_reward_room_contains_three_chests() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var chests: Array[Node] = []
	for child: Node in cave.get_node("interactables").get_children():
		if child is TreasureChest:
			chests.append(child)
	assert(chests.size() == 3)
	var expected_positions: Array[Vector2] = [
		Vector2(2743.0, 530.0),
		Vector2(2843.0, 530.0),
		Vector2(2943.0, 530.0),
	]
	var actual_positions: Array[Vector2] = []
	for chest: Node in chests:
		actual_positions.append((chest as Node2D).position)
	actual_positions.sort_custom(func(left: Vector2, right: Vector2) -> bool: return left.x < right.x)
	assert(actual_positions == expected_positions)
	cave.free()


func test_three_end_cave_chests_spread_coin_creation_across_frames() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(cave)
	await get_tree().process_frame
	var interactables: Node2D = cave.get_node("interactables") as Node2D
	var chests: Array[TreasureChest] = []
	for child: Node in interactables.get_children():
		var chest: TreasureChest = child as TreasureChest
		if chest != null:
			chests.append(chest)
	assert(chests.size() == 3)
	for chest: TreasureChest in chests:
		assert(chest.coin_spawn_batch_size == CaveIntroSequence.END_REWARD_CHEST_BATCH_SIZE)
		chest.call("_drop_coins")
	var previous_count: int = _count_coin_pickups(interactables)
	var maximum_added_in_one_frame: int = 0
	for _frame: int in range(24):
		await get_tree().process_frame
		var current_count: int = _count_coin_pickups(interactables)
		maximum_added_in_one_frame = maxi(maximum_added_in_one_frame, current_count - previous_count)
		previous_count = current_count
	assert(previous_count >= 54 and previous_count <= 81, "the three chests should keep their original coin quantity")
	assert(maximum_added_in_one_frame <= 9, "end-cave chests should not instantiate every reward coin in a single frame")
	cave.queue_free()
	await get_tree().process_frame

func _count_coin_pickups(parent: Node) -> int:
	var count: int = 0
	for child: Node in parent.get_children():
		if child is CoinPickup:
			count += 1
	return count

func test_chest_reward_amount_is_preserved() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var chest: TreasureChest = cave.get_node("interactables/chest") as TreasureChest
	var profile: Dictionary = chest.get_drop_profile()
	assert(int(profile["min_coins"]) == int(chest.coin_count_min * chest.coin_amount_multiplier / 2.0))
	assert(int(profile["max_coins"]) == int(chest.coin_count_max * chest.coin_amount_multiplier / 2.0))
	assert(float(profile["value_multiplier"]) == 1.0)
	cave.free()


func test_coin_registry_loads_existing_item_coin_art() -> void:
	var registry: Node = get_node("/root/CoinRegistry")
	registry.set("_initialized", false)
	(registry.get("_types") as Dictionary).clear()
	registry.call("_build_registry")
	var ids: Array[StringName] = registry.call("get_type_ids") as Array[StringName]
	assert(ids.size() == 5)
	assert(&"gold" in ids and &"steel" in ids)


func test_enemy_drop_manager_spawns_coin_pickups() -> void:
	var registry: Node = get_node("/root/CoinRegistry")
	registry.set("_initialized", false)
	(registry.get("_types") as Dictionary).clear()
	registry.call("_build_registry")
	var drop_parent: Node2D = Node2D.new()
	add_child(drop_parent)
	var manager: Node = get_node("/root/CoinDropManager")
	manager.call("drop_at", drop_parent, Vector2.ZERO, {"drop_chance": 1.0, "min_coins": 4, "max_coins": 4, "min_types": 1, "max_types": 3})
	var spawned_coins: int = 0
	for child: Node in drop_parent.get_children():
		if child is CoinPickup:
			spawned_coins += 1
	assert(spawned_coins == 4)
	drop_parent.queue_free()
	await get_tree().process_frame
