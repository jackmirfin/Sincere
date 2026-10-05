extends Node
class_name TestBlacksmith

const CURRENCY_MANAGER_SCRIPT: Script = preload("res://scripts/currency_manager.gd")


func test_weapon_starts_without_stats_and_tinker_rolls_three_for_50_coins() -> void:
	var manager: Node = CURRENCY_MANAGER_SCRIPT.new() as Node
	manager.set("total_currency", 100)
	var initial_stats: Array = manager.get("equipped_weapon_stats")
	assert(initial_stats.is_empty())
	assert(bool(manager.call("tinker_equipped_weapon")))
	assert(int(manager.get("total_currency")) == 50)
	var rolled_stats: Array = manager.get("equipped_weapon_stats")
	assert(rolled_stats.size() == 3)
	assert(rolled_stats[0] != rolled_stats[1])
	assert(rolled_stats[0] != rolled_stats[2])
	assert(rolled_stats[1] != rolled_stats[2])
	manager.free()


func test_tinker_does_not_change_stats_when_player_cannot_afford_it() -> void:
	var manager: Node = CURRENCY_MANAGER_SCRIPT.new() as Node
	manager.set("total_currency", 49)
	var before_stats: Array = manager.get("equipped_weapon_stats")
	assert(not bool(manager.call("tinker_equipped_weapon")))
	assert(int(manager.get("total_currency")) == 49)
	var after_stats: Array = manager.get("equipped_weapon_stats")
	assert(after_stats.is_empty())
	assert(before_stats == after_stats)
	manager.free()
