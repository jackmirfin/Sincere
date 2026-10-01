extends Node
class_name TestShopAndElevator

const SHOP_UI_SCENE: PackedScene = preload("res://scenes/shopui.tscn")
const MIDWORLD2_SCENE: PackedScene = preload("res://scenes/midworld_2.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")

func test_intro_run_moves_player_right_then_stops() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child(player)
	await get_tree().process_frame
	var start_x: float = player.global_position.x
	player.begin_intro_run(40.0, 100.0)
	for _i: int in range(90):
		await get_tree().physics_frame
	print("[intro] start=", start_x, " end=", player.global_position.x, " active=", player.intro_run_active, " rem=", player.intro_run_remaining)
	assert(player.intro_run_active == false)
	assert(player.global_position.x > start_x + 30.0)
	player.queue_free()
	await get_tree().process_frame

func test_shop_ui_has_the_three_requested_items() -> void:
	var shop: ShopUI = SHOP_UI_SCENE.instantiate() as ShopUI
	add_child(shop)
	await get_tree().process_frame
	assert(shop.items.size() == 3)
	assert(String(shop.items[0]["name"]) == "Whetstone")
	assert(int(shop.items[0]["price"]) == 110)
	assert(String(shop.items[0]["desc"]) == "Increase melee damage.")
	assert(String(shop.items[1]["name"]) == "Portable Charger")
	assert(int(shop.items[1]["price"]) == 125)
	assert(String(shop.items[1]["desc"]) == "Increase max health")
	assert(String(shop.items[2]["name"]) == "Coffee")
	assert(int(shop.items[2]["price"]) == 45)
	assert(String(shop.items[2]["desc"]) == "Increase movement speed")
	assert(shop.item_buttons.size() == 3)
	assert(shop.item_icons.size() == 3)
	assert(shop.coin_sprite != null)
	shop.queue_free()
	await get_tree().process_frame

func test_shop_ui_uses_the_shop_art_frame() -> void:
	var shop: ShopUI = SHOP_UI_SCENE.instantiate() as ShopUI
	add_child(shop)
	await get_tree().process_frame
	assert(shop.frame != null)
	var frame_texture: Texture2D = shop.frame.texture
	assert(frame_texture is AtlasTexture)
	assert((frame_texture as AtlasTexture).region == ShopUI.ART_REGION)
	# The frame keeps the artwork's aspect ratio.
	assert(is_equal_approx(shop.window.size.x / shop.window.size.y, ShopUI.FRAME_SIZE.x / ShopUI.FRAME_SIZE.y))
	# Every control sits inside the frame and lands on the box the art draws.
	for button: Button in shop.item_buttons:
		assert(button.position.x >= 0.0 and button.position.y >= 0.0)
		assert(button.position.x + button.size.x <= shop.window.size.x + 1.0)
		assert(button.position.y + button.size.y <= shop.window.size.y + 1.0)
	assert(shop.close_button.position.x > shop.window.size.x * 0.7)
	assert(shop.close_button.position.y < shop.window.size.y * 0.2)
	assert(shop.buy_button.position.y > shop.window.size.y * 0.6)
	# Hovering the close button must not paint an overlay over the art's X.
	var close_hover: StyleBoxFlat = shop.close_button.get_theme_stylebox("hover") as StyleBoxFlat
	assert(close_hover != null)
	assert(close_hover.bg_color.a < 0.2)
	shop.queue_free()
	await get_tree().process_frame

func test_buying_spends_coins_applies_effect_and_is_single_use() -> void:
	var currency: Node = get_node("/root/CurrencyManager")
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child(player)
	var shop: ShopUI = SHOP_UI_SCENE.instantiate() as ShopUI
	add_child(shop)
	await get_tree().process_frame
	currency.set("total_currency", 500)
	shop.open(player)
	assert(shop.shop_open)

	var base_damage: int = player.get_attack_damage()
	shop.selected_index = 0
	assert(shop.buy() == true)
	assert(int(currency.get("total_currency")) == 390)
	assert(player.get_attack_damage() == base_damage + 5)
	assert(shop.buy() == false)
	assert(int(currency.get("total_currency")) == 390)

	var base_speed: float = player.get_effective_move_speed()
	shop.selected_index = 2
	assert(shop.buy() == true)
	assert(is_equal_approx(player.move_speed_multiplier, 1.1))
	assert(player.get_effective_move_speed() > base_speed)

	var base_health: int = player.max_health
	shop.selected_index = 1
	assert(shop.buy() == true)
	assert(player.max_health > base_health)

	shop.close()
	assert(not shop.shop_open)
	assert(player.teleport_locked == false)
	player.queue_free()
	shop.queue_free()
	await get_tree().process_frame

func test_shop_cannot_afford_blocks_purchase() -> void:
	var currency: Node = get_node("/root/CurrencyManager")
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child(player)
	var shop: ShopUI = SHOP_UI_SCENE.instantiate() as ShopUI
	add_child(shop)
	await get_tree().process_frame
	currency.set("total_currency", 10)
	shop.open(player)
	shop.selected_index = 0
	assert(shop.buy() == false)
	assert(int(currency.get("total_currency")) == 10)
	shop.close()
	player.queue_free()
	shop.queue_free()
	await get_tree().process_frame

func test_midworld_2_wires_shop_elevator_and_exit() -> void:
	var world: Node2D = MIDWORLD2_SCENE.instantiate() as Node2D
	add_child(world)
	await get_tree().process_frame
	assert(world.get_node_or_null("shop") is Shop)
	assert(world.get_node_or_null("elevator") is Elevator)
	var endlevel: LevelEnd = world.get_node_or_null("endlevel") as LevelEnd
	assert(endlevel != null)
	assert(endlevel.next_scene == "res://scenes/twilightcave.tscn")
	assert(ResourceLoader.exists("res://scenes/twilightcave.tscn"))
	var knight: PlayerController = world.get_node_or_null("knight") as PlayerController
	assert(knight != null)
	var cam: Camera2D = knight.get_node_or_null("Camera2D") as Camera2D
	assert(cam != null)
	# The camera is pinned to x = 0 so the empty tiles left of the level are
	# never shown, and widened vertically so it follows the floor.
	assert(cam.limit_left == 0)
	assert(cam.limit_bottom == 1600)
	# The light layer parallaxes and draws above the player so the light also
	# falls across the knight sprite.
	var light_parallax: Parallax2D = world.get_node_or_null("lightparallax") as Parallax2D
	assert(light_parallax != null)
	assert(light_parallax.get_node_or_null("light") is TileMapLayer)
	assert(light_parallax.scroll_scale.x > 1.0)
	assert(light_parallax.z_index > knight.z_index)
	world.queue_free()
	await get_tree().process_frame

func test_elevator_needs_lever_and_rider_then_rises_at_seven_tiles_per_second() -> void:
	var world: Node2D = MIDWORLD2_SCENE.instantiate() as Node2D
	add_child(world)
	await get_tree().process_frame
	var elevator: Elevator = world.get_node("elevator") as Elevator
	assert(elevator != null)
	assert(elevator.tiles_per_second == 7.0)
	var expected_cables: int = int(ceil(elevator.global_position.y / 16.0)) + 1
	assert(elevator.cables.size() == expected_cables)
	assert(elevator.cables.size() > 1)

	elevator.set_physics_process(false)
	var rider: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child(rider)
	rider.global_position = Vector2(0.0, 0.0)

	elevator.call("_on_lever_flipped")
	assert(elevator.is_active() == false)
	assert(elevator.pending_activation == true)

	elevator.rider = rider
	elevator.call("_try_activate")
	assert(elevator.is_active() == true)
	assert(rider.elevator_ride_active == true)

	var start_y: float = elevator.global_position.y
	var start_rider_y: float = rider.global_position.y
	elevator.call("_physics_process", 1.0)
	assert(is_equal_approx(elevator.global_position.y, start_y - 7.0 * 16.0))
	assert(is_equal_approx(rider.global_position.y, start_rider_y - 7.0 * 16.0))

	rider.queue_free()
	world.queue_free()
	await get_tree().process_frame

func test_elevator_cable_animations_and_pulley_tuning() -> void:
	var world: Node2D = MIDWORLD2_SCENE.instantiate() as Node2D
	add_child(world)
	await get_tree().process_frame
	var elevator: Elevator = world.get_node("elevator") as Elevator
	assert(elevator.audio != null)
	assert(elevator.audio.pitch_scale == 1.0)
	for cable: AnimatedSprite2D in elevator.cables:
		assert(cable.animation == &"idle")
	assert(elevator.pulley_pitch_scale > 1.0)
	assert(elevator.pulley_volume_db < elevator.base_volume_db)
	elevator.call("_start_pulley_sound")
	assert(elevator.audio.pitch_scale == elevator.pulley_pitch_scale)
	assert(elevator.audio.volume_db == elevator.pulley_volume_db)
	elevator.call("_set_cables_active", true)
	for cable: AnimatedSprite2D in elevator.cables:
		assert(cable.animation == &"active")
	world.queue_free()
	await get_tree().process_frame

func test_elevator_pulley_sound_only_plays_while_riding() -> void:
	var world: Node2D = MIDWORLD2_SCENE.instantiate() as Node2D
	add_child(world)
	await get_tree().process_frame
	var elevator: Elevator = world.get_node("elevator") as Elevator
	assert(elevator.audio != null)
	# Idle elevator: the pulley must stay silent.
	assert(not elevator.audio.playing)

	var rider: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child(rider)
	# Standing on the platform before the lever is pulled is still silent.
	elevator.call("_on_rider_entered", rider)
	assert(elevator.rider == rider)
	assert(elevator.is_active() == false)
	assert(not elevator.audio.playing)

	# Pulling the lever starts the pulley.
	elevator.call("_on_lever_flipped")
	assert(elevator.is_active() == true)
	assert(elevator.audio.playing)
	assert(elevator.audio.pitch_scale == elevator.pulley_pitch_scale)
	assert(elevator.audio.volume_db == elevator.pulley_volume_db)

	# Stepping off stops it again.
	elevator.call("_on_rider_exited", rider)
	assert(elevator.rider == null)
	assert(not elevator.audio.playing)

	rider.queue_free()
	world.queue_free()
	await get_tree().process_frame