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


func test_chest_reward_is_tripled() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var chest: TreasureChest = cave.get_node("interactables/chest") as TreasureChest
	var profile: Dictionary = chest.get_drop_profile()
	assert(int(profile["min_coins"]) == chest.coin_count_min * 3)
	assert(int(profile["max_coins"]) == chest.coin_count_max * 3)
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
