extends Node
class_name TestOgreEnemy

const OGRE_SCENE: PackedScene = preload("res://scenes/orge.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const TWILIGHT_SCENE: PackedScene = preload("res://scenes/twilightcave.tscn")

func test_twilightcave_replaces_all_flying_eyes_with_ogres() -> void:
	var world: TwilightCave = TWILIGHT_SCENE.instantiate() as TwilightCave
	world.opening_sequence_running = true
	add_child(world)
	assert(world.background_music.stream == TwilightCave.TWILIGHT_MUSIC_B)
	var enemies: Node2D = world.get_node("enemies") as Node2D
	var ogre_count: int = 0
	var flying_eye_count: int = 0
	for enemy: Node in enemies.get_children():
		if enemy is OgreEnemy:
			ogre_count += 1
		elif enemy is FlyingEyeEnemy:
			flying_eye_count += 1
	assert(ogre_count == 14, "expected every Twilight Cave flying-eye placement to be an Ogre; found %d" % ogre_count)
	assert(flying_eye_count == 0, "Twilight Cave still contains flying eyes")
	world.queue_free()
	await get_tree().process_frame

func test_ogre_notices_player_then_runs_and_attacks() -> void:
	var world: Node2D = Node2D.new()
	add_child(world)
	var floor: StaticBody2D = StaticBody2D.new()
	floor.collision_layer = 1
	floor.position = Vector2(450.0, 5.0)
	var floor_shape: CollisionShape2D = CollisionShape2D.new()
	var floor_rectangle: RectangleShape2D = RectangleShape2D.new()
	floor_rectangle.size = Vector2(2600.0, 10.0)
	floor_shape.shape = floor_rectangle
	floor.add_child(floor_shape)
	world.add_child(floor)

	var ogre: OgreEnemy = OGRE_SCENE.instantiate() as OgreEnemy
	world.add_child(ogre)
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	world.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(900.0, 0.0)
	await get_tree().process_frame
	for _startup_frame: int in range(3):
		await get_tree().physics_frame
		if ogre.state == OgreEnemy.OgreState.NOTICE:
			break
	assert(ogre.state == OgreEnemy.OgreState.NOTICE,
		"ogre missed player: state=%d player=%s position=%s player_position=%s dist=%s visible=%s" % [ogre.state, str(ogre.player), str(ogre.global_position), str(player.global_position), str(ogre.global_position.distance_to(player.global_position)), str(ogre._can_see_player())])
	assert(ogre.animated_sprite.animation == &"notice")
	assert(ogre.get_node_or_null("attackindicator") != null)

	var run_seen: bool = false
	var indicator_seen_during_charge: bool = false
	var windup_seen: bool = false
	var attack_seen: bool = false
	for _frame: int in range(220):
		if ogre.state == OgreEnemy.OgreState.CHASE and ogre.animated_sprite.animation == &"run":
			run_seen = true
			indicator_seen_during_charge = ogre.charge_indicator != null and is_instance_valid(ogre.charge_indicator) and ogre.charge_indicator.loop_until_removed
		if ogre.state == OgreEnemy.OgreState.WINDUP:
			windup_seen = ogre.charge_indicator != null and is_instance_valid(ogre.charge_indicator)
		if ogre.state == OgreEnemy.OgreState.ATTACK:
			attack_seen = ogre.charge_indicator != null and is_instance_valid(ogre.charge_indicator)
			break
		await get_tree().physics_frame
	assert(ogre.attack_indicator_hit, "notice did not activate the overhead hit indicator")
	assert(run_seen, "Ogre did not run after the notice animation")
	assert(indicator_seen_during_charge, "Ogre's warning indicator did not stay overhead during the charge")
	assert(windup_seen, "Ogre did not telegraph before attacking")
	assert(attack_seen and ogre.animated_sprite.animation == &"attack", "Ogre attack warning disappeared during its swing")
	assert(is_equal_approx(ogre.charge_indicator.scale.x, 1.5), "Ogre attack indicator was not enlarged for visibility")
	assert(is_equal_approx(ogre.charge_indicator.position.y, -72.0), "Ogre attack indicator should sit closer to its head")
	world.queue_free()
	await get_tree().process_frame

func test_ogre_weapon_activates_only_on_the_three_requested_frames() -> void:
	var ogre: OgreEnemy = OGRE_SCENE.instantiate() as OgreEnemy
	add_child(ogre)
	await get_tree().process_frame
	assert(ogre.max_health == 60, "Ogre should be more durable than standard enemies")
	assert(ogre.move_speed >= 680.0 and ogre.move_speed < 750.0, "Ogre charge speed should be slightly slower")
	assert(ogre.attack_windup_duration >= 0.35, "Ogre attack wind-up is too short")
	assert(ogre.detection_range >= 1400.0, "Ogre does not spot players from far enough away")
	var muted_tint: ShaderMaterial = ogre.animated_sprite.material as ShaderMaterial
	assert(muted_tint != null)
	assert(is_equal_approx(ogre.animated_sprite.modulate.a, 1.0), "Ogre opacity should be restored to 100%")
	assert(is_equal_approx(float(muted_tint.get_shader_parameter("desaturation")), OgreEnemy.OGRE_DESATURATION))
	assert(is_equal_approx(float(muted_tint.get_shader_parameter("desaturation")), 0.10), "Ogre should retain 90% of its original saturation")
	assert(is_equal_approx(float(muted_tint.get_shader_parameter("overlay_strength")), OgreEnemy.OGRE_OVERLAY_STRENGTH))
	assert(is_equal_approx(float(muted_tint.get_shader_parameter("overlay_strength")), 0.10))
	assert(is_equal_approx(float(muted_tint.get_shader_parameter("brightness")), OgreEnemy.OGRE_BRIGHTNESS))
	assert(is_equal_approx(float(muted_tint.get_shader_parameter("brightness")), 1.0))
	assert(muted_tint.get_shader_parameter("overlay_color") == OgreEnemy.OGRE_OVERLAY_COLOR)
	assert(is_equal_approx(ogre.attack_audio.volume_db, -8.0))
	assert(ogre.animated_sprite.sprite_frames.has_animation(&"notice"))
	assert(ogre.animated_sprite.sprite_frames.has_animation(&"run"))
	assert(ogre.animated_sprite.sprite_frames.get_frame_count(&"attack") == 25)
	assert(OgreEnemy.ATTACK_HIT_FRAMES == [4, 8, 12])
	assert(OgreEnemy.ATTACK_TURNAROUND_FRAME == 15)
	assert(ogre.attack_audio.stream == OgreEnemy.ATTACK_SOUND)
	ogre.set_physics_process(false)
	ogre._change_state(OgreEnemy.OgreState.ATTACK)
	ogre.animated_sprite.pause()
	for impact_frame: int in OgreEnemy.ATTACK_HIT_FRAMES:
		ogre.animated_sprite.frame = impact_frame
		await get_tree().process_frame
		assert(not ogre.weapon_shape.disabled and ogre.weapon_hitbox.monitoring,
			"weapon was not active on attack frame %d" % impact_frame)
		assert(ogre.can_hit_player(), "Ogre should only hit on a configured attack frame")
		assert(ogre.attack_audio.playing, "bang.mp3 did not play on attack frame %d" % impact_frame)
		var expected_facing: int = -1 if impact_frame >= OgreEnemy.ATTACK_TURNAROUND_FRAME else 1
		assert(signi(int(signf(ogre.weapon_hitbox.position.x))) == expected_facing,
			"Ogre hitbox should follow its visible facing on attack frame %d" % impact_frame)
		ogre.animated_sprite.frame = impact_frame + 1
		await get_tree().process_frame
		assert(ogre.weapon_shape.disabled and not ogre.weapon_hitbox.monitoring,
			"weapon remained active after attack frame %d" % impact_frame)
		assert(not ogre.can_hit_player(), "Ogre damage should be rejected outside impact frames")
	ogre.animated_sprite.frame = OgreEnemy.ATTACK_TURNAROUND_FRAME
	await get_tree().process_frame
	assert(ogre.facing == -1 and ogre.animated_sprite.flip_h,
		"Ogre should turn around after its third strike")
	assert(ogre.attack_hit_count == 3)
	assert(ogre.attack_hit_frames_seen == [4, 8, 12])
	ogre.queue_free()
	await get_tree().process_frame

func test_ogre_keeps_attacking_when_damaged_or_parried() -> void:
	var ogre: OgreEnemy = OGRE_SCENE.instantiate() as OgreEnemy
	add_child(ogre)
	await get_tree().process_frame
	ogre.set_physics_process(false)
	ogre._change_state(OgreEnemy.OgreState.ATTACK)
	ogre.animated_sprite.pause()
	ogre.animated_sprite.frame = 6
	ogre.take_damage(1, 1, -1.0)
	assert(ogre.state == OgreEnemy.OgreState.ATTACK)
	assert(ogre.animated_sprite.animation == &"attack" and ogre.animated_sprite.frame == 6)
	ogre.stun_from_parry(0.8)
	assert(ogre.state == OgreEnemy.OgreState.ATTACK)
	assert(ogre.animated_sprite.animation == &"attack")
	ogre.queue_free()
	await get_tree().process_frame


func test_ogre_has_combat_shapes_and_can_be_defeated() -> void:
	var ogre: OgreEnemy = OGRE_SCENE.instantiate() as OgreEnemy
	ogre.max_health = 20
	add_child(ogre)
	await get_tree().process_frame
	assert(ogre.is_in_group("enemy"))
	assert(ogre.body_collision.shape != null)
	assert(ogre.hurtbox.get_node("CollisionShape2D") != null)
	assert(ogre.weapon_shape.disabled)
	ogre.take_damage(10)
	assert(ogre.health == 10 and ogre.state == OgreEnemy.OgreState.IDLE)
	ogre.take_damage(10)
	await get_tree().process_frame
	assert(ogre.dead and ogre.animated_sprite.animation == &"death")
	assert(ogre.body_collision.disabled)
	ogre.queue_free()
	await get_tree().process_frame
