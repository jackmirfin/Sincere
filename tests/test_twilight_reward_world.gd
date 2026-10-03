extends Node
class_name TestTwilightRewardWorld

const REWARD_WORLD_SCENE: PackedScene = preload("res://scenes/twilightrewardworld.tscn")
const TWILIGHT_CAVE_SCENE: PackedScene = preload("res://scenes/twilightcave.tscn")
const ROOM_ENTRY_STOP_Y: float = 272.0
const EXIT_STOP_Y: float = -56.0

func test_reward_world_exit_and_parallax_setup() -> void:
	var world: TwilightRewardWorld = REWARD_WORLD_SCENE.instantiate() as TwilightRewardWorld
	var player: PlayerController = world.get_node("knight") as PlayerController
	assert(player.position == Vector2(1052.0, 618.0), "knight should start on the elevator at its authored position")
	add_child(world)
	await get_tree().process_frame
	var endlevel: LevelEnd = world.get_node("endlevel") as LevelEnd
	var elevator: Elevator = world.get_node("elevator2") as Elevator
	var lever: CaveLever = world.get_node("lever2") as CaveLever
	var background_parallax: Parallax2D = world.get_node("BackgroundParallax") as Parallax2D
	var light_parallax: Parallax2D = world.get_node("LightParallax") as Parallax2D
	var player_camera: Camera2D = player.get_node("Camera2D") as Camera2D
	assert(player_camera.limit_left == 0, "camera should respect the left world edge during the elevator ride")
	var pedestal: RewardPedestal = world.get_node("rewardspedestal") as RewardPedestal
	for icon: Sprite2D in pedestal.slot_icons:
		assert(is_equal_approx(icon.position.y, -12.0), "reward icons should sit lower above the pedestal")
	assert(elevator.auto_start and elevator.stop_at_global_y)
	assert(is_equal_approx(elevator.stop_global_y, ROOM_ENTRY_STOP_Y))
	assert(elevator.retain_rider_at_stop)
	assert(lever.get_parent() == world and is_equal_approx(lever.global_position.y, 247.0))
	assert(endlevel.collision_layer == 0 and endlevel.collision_mask == 2)
	assert(endlevel.next_scene == "res://scenes/midworld_3.tscn")
	assert(ResourceLoader.exists(endlevel.next_scene))
	assert(background_parallax.get_node("background") is TileMapLayer)
	assert(background_parallax.scroll_scale.is_equal_approx(Vector2(0.92, 0.92)))
	assert(background_parallax.follow_viewport)
	assert(light_parallax.get_node("light") is TileMapLayer)
	assert(light_parallax.scroll_scale.is_equal_approx(Vector2(0.96, 0.96)))
	assert(light_parallax.follow_viewport)
	var initial_light_offset: Vector2 = light_parallax.screen_offset
	assert(world.get_node("platforms") is TileMapLayer, "collidable platforms should stay in world space")
	await get_tree().create_timer(1.9).timeout
	assert(not initial_light_offset.is_equal_approx(light_parallax.screen_offset), "light parallax should scroll with the camera during the elevator ride")
	assert(is_equal_approx(elevator.global_position.y, ROOM_ENTRY_STOP_Y), "startup ride should stop at the room entrance")
	assert(world.entry_ride_complete)
	assert(elevator.rider == player, "keep the rider reference so the lever can start the next elevator leg")
	assert(is_equal_approx(elevator.stop_global_y, EXIT_STOP_Y), "the lever ride should target the endlevel trigger")
	lever.flip()
	var waited: float = 0.0
	while not lever.flipped_state and waited < 1.5:
		await get_tree().process_frame
		waited += get_process_delta_time()
	assert(lever.flipped_state)
	assert(elevator.activated and player.elevator_ride_active, "pressing the lever should start the second lift")
	assert(is_equal_approx(elevator.stop_global_y, EXIT_STOP_Y))
	world.queue_free()
	await get_tree().process_frame

func test_twilight_cave_exit_routes_to_reward_world() -> void:
	var cave: Node2D = TWILIGHT_CAVE_SCENE.instantiate() as Node2D
	var endlevel: LevelEnd = cave.get_node("endlevel") as LevelEnd
	assert(endlevel.collision_layer == 0 and endlevel.collision_mask == 2)
	assert(endlevel.next_scene == "res://scenes/twilightrewardworld.tscn")
	assert(ResourceLoader.exists(endlevel.next_scene))
	cave.free()
