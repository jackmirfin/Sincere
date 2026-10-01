extends Node
class_name TestCoinCount

const COIN_SCENE: PackedScene = preload("res://scenes/coin_pickup.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/control.tscn")


func _currency() -> Node:
	return get_node("/root/CurrencyManager")


func test_recording_a_coin_tracks_count_value_and_balance() -> void:
	var currency: Node = _currency()
	currency.set("total_currency", 0)
	currency.set("coins_collected", 0)
	currency.set("currency_earned", 0)
	var received: Array = []
	var handler: Callable = func(value: int, collected: int, balance: int) -> void:
		received.append([value, collected, balance])
	currency.coin_collected.connect(handler)

	currency.call("record_coin", 3)
	currency.call("record_coin", 5)

	assert(int(currency.get("coins_collected")) == 2)
	assert(int(currency.get("currency_earned")) == 8)
	assert(int(currency.get("total_currency")) == 8)
	assert(int(currency.call("get_coins_collected")) == 2)
	assert(int(currency.call("get_balance")) == 8)
	assert(received.size() == 2)
	assert(int((received[1] as Array)[1]) == 2)
	assert(int((received[1] as Array)[2]) == 8)
	currency.coin_collected.disconnect(handler)


func test_spending_keeps_the_picked_up_record() -> void:
	var currency: Node = _currency()
	currency.set("total_currency", 0)
	currency.set("coins_collected", 0)
	currency.set("currency_earned", 0)

	currency.call("record_coin", 10)
	assert(bool(currency.call("spend_currency", 4)))
	assert(int(currency.get("total_currency")) == 6)
	assert(int(currency.get("coins_collected")) == 1)
	assert(int(currency.get("currency_earned")) == 10)


func test_picked_up_coin_records_through_the_manager() -> void:
	var currency: Node = _currency()
	currency.set("total_currency", 0)
	currency.set("coins_collected", 0)
	currency.set("currency_earned", 0)

	var coin: CoinPickup = COIN_SCENE.instantiate() as CoinPickup
	coin.stable_id = &"gold"
	add_child(coin)
	await get_tree().process_frame

	coin.call("_collect")

	assert(int(currency.get("coins_collected")) == 1)
	assert(int(currency.get("total_currency")) > 0)
	await get_tree().process_frame
	# The pickup plays its jingle on a node parented to the tree root; headless
	# audio never finishes, so clear it explicitly to avoid leaking the stream.
	for child: Node in get_tree().root.get_children():
		if child is AudioStreamPlayer2D:
			child.free()
	if is_instance_valid(coin):
		coin.free()
	await get_tree().process_frame


func test_pause_menu_shows_coin_count_beside_the_battery() -> void:
	var currency: Node = _currency()
	currency.set("total_currency", 42)

	var menu: PauseMenu = PAUSE_SCENE.instantiate() as PauseMenu
	add_child(menu)
	await get_tree().process_frame
	menu.call("_refresh_coin_count")

	var coin_label: Label = menu.get("coin_label") as Label
	assert(coin_label != null)
	assert(coin_label.text == "42")

	var coin_row: Control = menu.get("coin_row") as Control
	var battery: ColorRect = menu.get("battery_empty") as ColorRect
	var artwork: TextureRect = menu.get("artwork") as TextureRect
	assert(coin_row != null)
	# Same device row as the battery (battery sits at artwork pixel 53,20 in an
	# 85px-wide source, so its screen row is 20 * 308 / 85).
	var battery_row_y: float = battery.position.y - artwork.position.y
	var coin_row_top: float = coin_row.position.y - artwork.position.y
	var coin_row_bottom: float = coin_row_top + coin_row.size.y * artwork.scale.y
	assert(coin_row_bottom > battery_row_y)
	assert(coin_row_top < battery_row_y + battery.size.y)
	# ...and to its left, not overlapping it.
	assert(coin_row.position.x + coin_row.size.x * artwork.scale.x <= battery.position.x + 1.0)

	currency.set("total_currency", 77)
	menu.call("_refresh_coin_count")
	assert(coin_label.text == "77")

	menu.queue_free()
	await get_tree().process_frame