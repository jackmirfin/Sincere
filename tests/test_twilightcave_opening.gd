extends Node

const CAVE_SCENE: PackedScene = preload("res://scenes/twilightcave.tscn")
const KNIGHT_FEET_OFFSET: float = 4.0

var roof_was_at_departure_stop_when_camera_returned: bool = false

func _on_opening_camera_returned(elevator: Elevator) -> void:
	roof_was_at_departure_stop_when_camera_returned = is_equal_approx(elevator.global_position.y, TwilightCave.ROOF_ELEVATOR_STOP_Y)

func test_cave_gates_fit_their_openings() -> void:
	assert(is_equal_approx(TwilightCave.CUTSCENE_DASH_DURATION, CaveIntroSequence.DASH_DURATION), "Twilight camera dash timing differs from the main cave")
	assert(is_equal_approx(TwilightCave.CUTSCENE_STOP_DURATION, CaveIntroSequence.STOP_DURATION), "Twilight camera stop timing differs from the main cave")
	assert(is_equal_approx(TwilightCave.KING_EXIT_DURATION, CaveIntroSequence.KING_EXIT_DURATION), "King departure timing differs from the main cave")
	var world: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(world)
	world.opening_sequence_running = true
	var interactables: Node2D = world.get_node("interactables") as Node2D
	assert(_gate_fits(interactables.get_node("gate1") as CaveGate, 304.0, 352.0), "gate1 overlaps the platform edges")
	assert(_gate_fits(interactables.get_node("gate2") as CaveGate, 240.0, 320.0), "gate2 overlaps the platform edges")
	assert(_gate_fits(interactables.get_node("gate3") as CaveGate, 304.0, 368.0), "gate3 overlaps the platform edges")
	assert(_gate_fits(interactables.get_node("endgate") as CaveGate, 16.0, 176.0), "endgate overlaps the upper or lower platform")
	world.queue_free()
	await get_tree().process_frame

func test_twilight_music_starts_b_then_overlaps_looping_a_and_b() -> void:
	var world: Node2D = CAVE_SCENE.instantiate() as Node2D
	world.opening_sequence_running = true
	add_child(world)
	await get_tree().process_frame
	assert(world.background_music.stream == TwilightCave.TWILIGHT_MUSIC_B)
	assert(not world.twilight_a_music.playing)
	world._start_twilight_music()
	assert(world.background_music.playing)
	world._on_background_music_finished()
	assert(world.background_music.playing, "Twilight B should restart after its intro play")
	assert(world.twilight_a_music.playing, "Twilight A should start when Twilight B finishes its intro play")
	assert(world.twilight_a_music.stream == TwilightCave.TWILIGHT_MUSIC_A)
	assert(world.twilight_a_music.volume_db < world.background_music.volume_db, "Twilight A should be slightly quieter than Twilight B")
	world._on_background_music_finished()
	assert(world.background_music.playing, "Twilight B should keep looping under Twilight A")
	world._on_twilight_a_music_finished()
	assert(world.twilight_a_music.playing, "Twilight A should loop over Twilight B")
	world.queue_free()
	await get_tree().process_frame

func test_twilight_light_layer_has_subtle_parallax() -> void:
	var world: Node2D = CAVE_SCENE.instantiate() as Node2D
	world.opening_sequence_running = true
	add_child(world)
	await get_tree().process_frame
	var light_parallax: Parallax2D = world.get_node("LightParallax") as Parallax2D
	var light_layer: TileMapLayer = light_parallax.get_node("light") as TileMapLayer
	var background_parallax: Parallax2D = world.get_node("BackgroundParallax") as Parallax2D
	var platforms: TileMapLayer = world.get_node("platforms") as TileMapLayer
	assert(light_layer != null and light_layer.z_index == 1000)
	assert(is_equal_approx(light_parallax.scroll_scale.x, 0.96))
	assert(is_equal_approx(light_parallax.scroll_scale.y, 0.96))
	assert(is_equal_approx(background_parallax.scroll_scale.x, 0.92))
	assert(is_equal_approx(background_parallax.scroll_scale.y, 0.92))
	assert(platforms.get_parent() == world, "Collidable platforms should stay camera-locked in world space")
	assert(background_parallax.scroll_scale.x < light_parallax.scroll_scale.x)
	assert(light_parallax.scroll_scale.x < 1.0, "Platforms should move more than the light layer")
	world.queue_free()
	await get_tree().process_frame

func _gate_fits(gate: CaveGate, opening_top: float, opening_bottom: float) -> bool:
	var half_height: float = 21.0 * absf(gate.scale.y)
	return gate.position.y - half_height >= opening_top - 0.1 and gate.position.y + half_height <= opening_bottom + 0.1

func test_wall_and_ceiling_spiders_leap_at_an_approaching_player() -> void:
	var world: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(world)
	world.opening_sequence_running = true
	await get_tree().process_frame
	var player: PlayerController = world.get_node("knight") as PlayerController
	var big_ceiling_spider: BigSpiderEnemy = world.get_node("enemies/bigspider5") as BigSpiderEnemy
	var small_ceiling_spider: SmallSpiderEnemy = world.get_node("enemies/smallspider6") as SmallSpiderEnemy
	var wall_spider: SmallSpiderEnemy = world.get_node("enemies/smallspider5") as SmallSpiderEnemy
	player.set_physics_process(false)
	for _attach_frame: int in range(3):
		await get_tree().physics_frame
	assert(big_ceiling_spider.crawler.attached and big_ceiling_spider.crawler.surface_normal.y > 0.9)
	assert(small_ceiling_spider.crawler.attached and small_ceiling_spider.crawler.surface_normal.y > 0.9,
		"small ceiling attach failed: attached=%s normal=%s position=%s" % [str(small_ceiling_spider.crawler.attached), str(small_ceiling_spider.crawler.surface_normal), str(small_ceiling_spider.global_position)])
	assert(wall_spider.crawler.attached and wall_spider.crawler.surface_normal.x > 0.9)

	player.global_position = big_ceiling_spider.global_position + Vector2(0.0, 40.0)
	for _attack_frame: int in range(4):
		await get_tree().physics_frame
	assert(big_ceiling_spider.attack_leaping and big_ceiling_spider.velocity.y > 0.0,
		"big spider did not drop: state=%d leap=%s velocity=%s normal=%s pos=%s player=%s floor=%s" % [big_ceiling_spider.state, str(big_ceiling_spider.attack_leaping), str(big_ceiling_spider.velocity), str(big_ceiling_spider.crawler.surface_normal), str(big_ceiling_spider.global_position), str(player.global_position), str(big_ceiling_spider.is_on_floor())])
	big_ceiling_spider.set_physics_process(false)

	player.global_position = small_ceiling_spider.global_position + Vector2(0.0, 40.0)
	for _attack_frame: int in range(4):
		await get_tree().physics_frame
	assert(small_ceiling_spider.attack_leaping and small_ceiling_spider.velocity.y > 0.0,
		"small spider did not drop from its ceiling toward the player")
	small_ceiling_spider.set_physics_process(false)

	player.global_position = wall_spider.global_position + Vector2(40.0, 0.0)
	for _attack_frame: int in range(4):
		await get_tree().physics_frame
	assert(wall_spider.attack_leaping and wall_spider.velocity.x > 0.0,
		"wall spider did not leap from its wall toward the player")
	world.queue_free()
	await get_tree().process_frame

func test_opening_returns_camera_and_leaves_roof_elevator_ready() -> void:
	var world: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(world)
	var player: PlayerController = world.get_node("knight") as PlayerController
	var player_camera: Camera2D = player.get_node("Camera2D") as Camera2D
	var roof: Elevator = world.get_node("elevators/elevator2") as Elevator
	var lever: CaveLever = world.get_node("interactables/lever3") as CaveLever
	var ceiling_spider: BigSpiderEnemy = world.get_node("enemies/bigspider5") as BigSpiderEnemy
	var scaled_ceiling_spider: BigSpiderEnemy = world.get_node("enemies/bigspider6") as BigSpiderEnemy
	var small_ceiling_spider: SmallSpiderEnemy = world.get_node("enemies/smallspider6") as SmallSpiderEnemy
	var wall_spider: SmallSpiderEnemy = world.get_node("enemies/smallspider5") as SmallSpiderEnemy
	roof_was_at_departure_stop_when_camera_returned = false
	world.opening_camera_returned_to_player.connect(_on_opening_camera_returned.bind(roof))
	await get_tree().process_frame
	var king_teleport_seen: bool = false
	var king_teleport_seen_while_camera_panned_to_lever: bool = false
	var king_visible_for_first_time: bool = false
	var king_was_visible: bool = false
	var king_frame_when_first_visible: int = -1
	var king_animation_when_first_visible: StringName = &""
	var king_first_visible_camera_center: Vector2 = Vector2.ZERO
	var king_first_visible_position: Vector2 = Vector2.ZERO
	var king_first_visible_half_extent: Vector2 = Vector2.ZERO
	var previous_lever_camera_distance: float = INF
	var king_light_overlay_order_verified: bool = false
	var king_walk_seen: bool = false
	var pulley_fade_seen: bool = false
	var lever_animation_seen: bool = false
	for _surface_frame: int in range(3):
		await get_tree().physics_frame
	assert(ceiling_spider.crawler.attached and ceiling_spider.crawler.surface_normal.y > 0.9,
		"big spider ceiling attach failed: attached=%s normal=%s position=%s" % [str(ceiling_spider.crawler.attached), str(ceiling_spider.crawler.surface_normal), str(ceiling_spider.global_position)])
	assert(scaled_ceiling_spider.crawler.attached,
		"scaled big spider failed to attach to a surface: normal=%s position=%s" % [str(scaled_ceiling_spider.crawler.surface_normal), str(scaled_ceiling_spider.global_position)])
	assert(small_ceiling_spider.crawler.attached and small_ceiling_spider.crawler.surface_normal.y > 0.9,
		"small spider did not attach to its ceiling start")
	assert(wall_spider.crawler.attached and wall_spider.crawler.surface_normal.x > 0.9,
		"small spider did not attach: attached=%s normal=%s position=%s" % [str(wall_spider.crawler.attached), str(wall_spider.crawler.surface_normal), str(wall_spider.global_position)])
	wall_spider.set_physics_process(false)
	var opening_finished: bool = false
	var pulley_sound_started: bool = false
	var cinematic_camera_seen: bool = false
	var lever_camera_hold_verified: bool = false
	var opening_started: bool = false
	for _i: int in range(1800):
		pulley_sound_started = pulley_sound_started or roof.audio.playing
		pulley_fade_seen = pulley_fade_seen or (roof.audio.playing and roof.audio.volume_db < roof.pulley_volume_db - 0.1)
		var cinematic_camera: Camera2D = world.get_node_or_null("TwilightOpeningCamera") as Camera2D
		var active_king: CharacterBody2D = world.get_node_or_null("king") as CharacterBody2D
		if active_king != null:
			var king_sprite: AnimatedSprite2D = active_king.get_node("AnimatedSprite2D") as AnimatedSprite2D
			var light_parallax: Parallax2D = world.get_node("LightParallax") as Parallax2D
			var camera_distance_to_lever: float = cinematic_camera.global_position.distance_to(lever.global_position) if cinematic_camera != null else 0.0
			king_light_overlay_order_verified = active_king.get_index() < light_parallax.get_index()
			if king_sprite.animation == &"teleport":
				king_teleport_seen = true
				if camera_distance_to_lever < previous_lever_camera_distance - 0.1:
					king_teleport_seen_while_camera_panned_to_lever = true
			previous_lever_camera_distance = camera_distance_to_lever
			king_walk_seen = king_walk_seen or king_sprite.animation == &"walk"
		lever_animation_seen = lever_animation_seen or lever.animation == &"flipping" or lever.animation == &"flipped"
		if cinematic_camera != null:
			cinematic_camera_seen = true
			assert(cinematic_camera.is_current(), "another camera took over during the King cutscene")
			assert(cinematic_camera.limit_enabled and cinematic_camera.limit_left == 0,
				"King cutscene camera lost the x=0 left boundary")
			var visible_left_x: float = cinematic_camera.get_screen_center_position().x - get_viewport().get_visible_rect().size.x / (2.0 * cinematic_camera.zoom.x)
			assert(visible_left_x >= -1.0, "King cutscene camera showed past the x=0 world boundary")
			if active_king != null:
				var viewport_half_extent: Vector2 = world._cutscene_viewport_size(cinematic_camera) / (cinematic_camera.zoom * 2.0)
				var camera_center: Vector2 = cinematic_camera.get_screen_center_position()
				var king_offset: Vector2 = active_king.global_position - camera_center
				var king_is_visible: bool = absf(king_offset.x) <= viewport_half_extent.x and absf(king_offset.y) <= viewport_half_extent.y
				if king_is_visible and not king_was_visible:
					king_visible_for_first_time = true
					var visibility_sprite: AnimatedSprite2D = active_king.get_node("AnimatedSprite2D") as AnimatedSprite2D
					king_animation_when_first_visible = visibility_sprite.animation
					king_first_visible_camera_center = camera_center
					king_first_visible_position = active_king.global_position
					king_first_visible_half_extent = viewport_half_extent
					if visibility_sprite.animation == &"teleport":
						king_frame_when_first_visible = visibility_sprite.frame
				king_was_visible = king_is_visible
			if active_king != null and roof.global_position.y < 175.0:
				lever_camera_hold_verified = true
				assert(absf(cinematic_camera.global_position.y - lever.global_position.y) < 1.0,
					"camera followed the elevator instead of holding on lever 3")
		if world.opening_sequence_running or cinematic_camera != null:
			opening_started = true
		if opening_started and not world.opening_sequence_running and player_camera.is_current():
			opening_finished = true
			break
		await get_tree().physics_frame
	assert(cinematic_camera_seen, "King cutscene camera was never created")
	assert(king_teleport_seen, "King did not spawn with the teleport animation")
	assert(king_teleport_seen_while_camera_panned_to_lever, "King teleport did not play while the camera panned directly to lever 3")
	assert(king_visible_for_first_time, "King never entered the cinematic camera view")
	assert(king_frame_when_first_visible >= 1 and king_frame_when_first_visible <= 2,
		"King should be on teleport frame 2 or 3 when first visible; frame=%d animation=%s center=%s position=%s half_extent=%s" % [king_frame_when_first_visible, String(king_animation_when_first_visible), str(king_first_visible_camera_center), str(king_first_visible_position), str(king_first_visible_half_extent)])
	assert(king_light_overlay_order_verified, "King rendered above the Twilight Cave light overlay")
	assert(king_walk_seen, "the King did not walk onto the elevator platform")
	assert(lever_animation_seen, "lever 3 did not play its flip animation during the cutscene")
	assert(lever_camera_hold_verified, "camera hold at the lever was not observed during the King's departure")
	assert(pulley_sound_started, "King's departure did not play the elevator sound")
	assert(pulley_fade_seen, "the elevator sound did not fade during the camera return pan")
	assert(opening_finished, "opening did not return to the player's camera")
	assert(roof_was_at_departure_stop_when_camera_returned,
		"the roof elevator reset before the camera returned to the player")
	assert(not roof.audio.playing, "cutscene pulley sound kept running after the King left")
	assert(not player.teleport_locked, "player stayed locked after the opening")
	assert(is_equal_approx(roof.global_position.y, 176.0), "cutscene did not restore the roof elevator")
	assert(not roof.activated and not roof.pending_activation and not roof.auto_start,
		"cutscene left the roof elevator in a non-idle state")
	assert(not lever.flipped_state and lever.animation == &"unflipped",
		"cutscene did not restore lever 3 for normal player use")

	var wall_start_y: float = wall_spider.global_position.y
	player.global_position = wall_spider.global_position + Vector2(0.0, 100.0)
	wall_spider.set_physics_process(true)
	for _crawl_frame: int in range(15):
		await get_tree().physics_frame
	assert(wall_spider.crawler.attached and wall_spider.crawler.surface_normal.x > 0.9,
		"small spider detached while moving on its wall")
	assert(wall_spider.global_position.y > wall_start_y + 5.0,
		"small spider did not move down the wall toward the player")

	player.global_position = Vector2(roof.global_position.x, roof.global_position.y - KNIGHT_FEET_OFFSET)
	for _i: int in range(30):
		await get_tree().physics_frame
	assert(roof.rider == player, "player could not board the roof elevator after the cutscene")
	lever.flip()
	for _i: int in range(60):
		await get_tree().physics_frame
	assert(roof.activated, "lever 3 did not activate the roof elevator after the cutscene")
	world.queue_free()
	await get_tree().process_frame
