extends Node

const MAX_PHYSICAL_COINS: int = 72
const COIN_SCENE: PackedScene = preload("res://scenes/coin_pickup.tscn")

var random: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	random.randomize()

func drop_at(parent: Node2D, origin: Vector2, profile: Dictionary = {}) -> void:
	if parent == null or not is_inside_tree():
		return
	var chance: float = float(profile.get("drop_chance", 1.0))
	if random.randf() > chance:
		return
	var registry: Node = get_node_or_null("/root/CoinRegistry")
	if registry == null:
		return
	var ids: Array[StringName] = registry.call("get_type_ids") as Array[StringName]
	if ids.is_empty():
		return
	var total: int = random.randi_range(int(profile.get("min_coins", 4)), int(profile.get("max_coins", 9)))
	total = clampi(total, 1, MAX_PHYSICAL_COINS)
	var min_types: int = clampi(int(profile.get("min_types", 1)), 1, ids.size())
	var max_types: int = clampi(int(profile.get("max_types", min_types)), min_types, ids.size())
	var distinct_count: int = random.randi_range(min_types, max_types)
	var selected: Array[StringName] = _weighted_without_replacement(registry, ids, distinct_count)
	var value_multiplier: float = maxf(0.01, float(profile.get("value_multiplier", 1.0)))
	var counts: Array[int] = []
	for _index: int in range(selected.size()):
		counts.append(1)
	var remaining: int = total - selected.size()
	while remaining > 0:
		var index: int = random.randi_range(0, counts.size() - 1)
		counts[index] += 1
		remaining -= 1
	var coin_ids: Array[StringName] = []
	var launch_velocities: Array[Vector2] = []
	var spawn_positions: Array[Vector2] = []
	for index: int in range(selected.size()):
		for _coin_index: int in range(counts[index]):
			coin_ids.append(selected[index])
			launch_velocities.append(Vector2(random.randf_range(-75.0, 75.0), random.randf_range(-165.0, -105.0)))
			spawn_positions.append(origin + Vector2(random.randf_range(-8.0, 8.0), random.randf_range(-6.0, 4.0)))
	var spawn_per_frame: int = int(profile.get("spawn_per_frame", 0))
	if spawn_per_frame <= 0 or spawn_per_frame >= total:
		for coin_index: int in range(total):
			_spawn_coin(parent, coin_ids[coin_index], launch_velocities[coin_index], spawn_positions[coin_index], value_multiplier)
	else:
		call_deferred("_spawn_coins_batched", parent, coin_ids, launch_velocities, spawn_positions, value_multiplier, spawn_per_frame)

func _spawn_coins_batched(parent: Node2D, coin_ids: Array[StringName], launch_velocities: Array[Vector2], spawn_positions: Array[Vector2], value_multiplier: float, batch_size: int) -> void:
	var spawned_this_frame: int = 0
	for coin_index: int in range(coin_ids.size()):
		if not is_instance_valid(parent):
			return
		_spawn_coin(parent, coin_ids[coin_index], launch_velocities[coin_index], spawn_positions[coin_index], value_multiplier)
		spawned_this_frame += 1
		if spawned_this_frame >= batch_size and coin_index + 1 < coin_ids.size():
			spawned_this_frame = 0
			await get_tree().process_frame

func _spawn_coin(parent: Node2D, coin_id: StringName, launch_velocity: Vector2, spawn_position: Vector2, value_multiplier: float) -> void:
	if not is_instance_valid(parent):
		return
	var coin: CoinPickup = COIN_SCENE.instantiate() as CoinPickup
	coin.configure(coin_id, launch_velocity, value_multiplier)
	parent.add_child(coin)
	coin.global_position = spawn_position

func _weighted_without_replacement(registry: Node, ids: Array[StringName], count: int) -> Array[StringName]:
	var remaining: Array[StringName] = ids.duplicate()
	var selected: Array[StringName] = []
	while selected.size() < count and not remaining.is_empty():
		var total_weight: float = 0.0
		for id: StringName in remaining:
			var data: CoinTypeData = registry.call("get_type", id) as CoinTypeData
			total_weight += maxf(0.0, data.selection_weight if data != null else 1.0)
		var roll: float = random.randf() * total_weight
		for index: int in range(remaining.size()):
			var candidate: StringName = remaining[index]
			var candidate_data: CoinTypeData = registry.call("get_type", candidate) as CoinTypeData
			roll -= maxf(0.0, candidate_data.selection_weight if candidate_data != null else 1.0)
			if roll <= 0.0:
				selected.append(candidate)
				remaining.remove_at(index)
				break
	return selected
