extends Node

signal currency_changed(total: int, delta: int)
signal coin_collected(value: int, coins_collected: int, balance: int)

var total_currency: int = 0
var coins_collected: int = 0
var currency_earned: int = 0
var purchased_shop_items: Dictionary = {}
var torch_duration_multiplier: float = 1.0
var equipped_weapon_name: String = "Sword"
var equipped_weapon_icon_path: String = "res://assets/items/sword.png"
var equipped_weapon_stats: Array[String] = []

const BLACKSMITH_TINKER_COST: int = 50
const BLACKSMITH_STAT_POOL: Array[String] = [
	"+20% damage to burning enemies",
	"+15% damage while speed-boosted",
	"+10% damage to electrified enemies",
	"+20% damage to poisoned enemies",
	"+1 additional charm slot",
	"+15% damage to bleeding enemies",
	"+10% damage to frozen enemies",
	"+10% critical damage",
	"+15% damage after a successful parry",
]

func add_currency(amount: int) -> void:
	if amount <= 0:
		return
	total_currency += amount
	currency_changed.emit(total_currency, amount)

## Records a single coin picked up: bumps the running pickup count, the
## lifetime value earned, and the spendable balance in one step.
func record_coin(value: int) -> void:
	if value <= 0:
		return
	coins_collected += 1
	currency_earned += value
	total_currency += value
	currency_changed.emit(total_currency, value)
	coin_collected.emit(value, coins_collected, total_currency)

## Number of individual coins picked up this session.
func get_coins_collected() -> int:
	return coins_collected

## Total value of every coin picked up this session (unaffected by spending).
func get_currency_earned() -> int:
	return currency_earned

## Current spendable balance.
func get_balance() -> int:
	return total_currency

func can_afford(amount: int) -> bool:
	return total_currency >= amount

func spend_currency(amount: int) -> bool:
	if amount <= 0:
		return true
	if total_currency < amount:
		return false
	total_currency -= amount
	currency_changed.emit(total_currency, -amount)
	return true

func record_shop_purchase(item_id: StringName) -> void:
	purchased_shop_items[item_id] = true

func has_purchased_shop_item(item_id: StringName) -> bool:
	return bool(purchased_shop_items.get(item_id, false))

func extend_torch_duration(multiplier: float = 1.5) -> void:
	if multiplier > 1.0:
		torch_duration_multiplier *= multiplier

func tinker_equipped_weapon() -> bool:
	if not spend_currency(BLACKSMITH_TINKER_COST):
		return false
	var available_stats: Array[String] = BLACKSMITH_STAT_POOL.duplicate()
	available_stats.shuffle()
	equipped_weapon_stats.clear()
	for index: int in range(3):
		equipped_weapon_stats.append(available_stats[index])
	return true

func apply_purchased_upgrades(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	if has_purchased_shop_item(&"whetstone") and player.has_method("add_attack_damage"):
		player.call("add_attack_damage", 5)
	if has_purchased_shop_item(&"portablecharger") and player.has_method("add_max_health_percent"):
		player.call("add_max_health_percent", 0.10)
	if has_purchased_shop_item(&"coffee") and player.has_method("add_move_speed_percent"):
		player.call("add_move_speed_percent", 0.10)
