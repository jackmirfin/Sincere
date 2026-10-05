extends Node
class_name TestBlacksmithUI

const BLACKSMITH_UI_SCENE: PackedScene = preload("res://scenes/blacksmith_ui.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")


func test_blacksmith_ui_contains_frame_and_works_with_equipped_weapon() -> void:
	var currency: Node = get_node_or_null("/root/CurrencyManager")
	assert(currency != null)
	var original_balance: int = int(currency.get("total_currency"))
	var original_stats_variant: Variant = currency.get("equipped_weapon_stats")
	var original_stats: Array[String] = []
	for stat: Variant in original_stats_variant:
		original_stats.append(String(stat))
	currency.set("total_currency", 50)

	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child(player)
	var ui: BlacksmithUI = BLACKSMITH_UI_SCENE.instantiate() as BlacksmithUI
	add_child(ui)
	await get_tree().process_frame
	assert(ui.get_node_or_null("Window/BlacksmithFrame") != null)
	assert(ui.frame.texture is AtlasTexture)
	assert((ui.frame.texture as AtlasTexture).region == BlacksmithUI.ART_REGION)
	assert(ui.get_node_or_null("Window/EquippedItemIcon") != null)
	assert(ui.get_node_or_null("Window/ItemNameBox") != null)
	assert(ui.get_node_or_null("Window/StatsNameBox") != null)
	assert(ui.get_node_or_null("Window/TinkerButton") != null)
	assert(not ui.visible)

	ui.open(player)
	assert(ui.visible)
	assert(ui.item_name_label.text == "Sword")
	assert(ui.item_icon.texture == load("res://assets/items/sword.png"))
	assert(ui.stats_label.text == "No stats yet")
	assert(not ui.tinker_button.disabled)
	assert(ui.tinker())
	assert(int(currency.get("total_currency")) == 0)
	var rolled_stats: Array = currency.get("equipped_weapon_stats")
	assert(rolled_stats.size() == 3)
	ui.close()
	assert(not player.teleport_locked)

	ui.queue_free()
	player.queue_free()
	currency.set("total_currency", original_balance)
	currency.set("equipped_weapon_stats", original_stats)
	await get_tree().process_frame
