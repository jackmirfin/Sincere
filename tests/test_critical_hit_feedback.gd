extends Node
class_name TestCriticalHitFeedback

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://scenes/goblin.tscn")

func test_sword_critical_pitches_hit_and_spawns_blood() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	var goblin: GoblinEnemy = GOBLIN_SCENE.instantiate() as GoblinEnemy
	player.auto_start = false
	add_child(player)
	add_child(goblin)
	await get_tree().process_frame
	player.set_physics_process(false)
	goblin.set_physics_process(false)
	player.state = PlayerController.PlayerState.ATTACK1
	player.speed_boost_time = 1.0
	var base_pitch: float = goblin.hurt_audio.pitch_scale
	var base_volume: float = goblin.hurt_audio.volume_db
	var prior_blood_count: int = _get_blood_effects().size()
	var prior_ding_count: int = _get_critical_dings().size()
	player.attack_hitbox.set_meta("attack_id", 1)
	assert(player.is_attack_critical(), "sword hits during an active speed boost should be critical")
	assert(HitEffect.apply_attack_damage(goblin, player, [1, 1, 1.0]), "sword hit should register as critical")
	assert(goblin.hurt_audio.pitch_scale >= base_pitch * HitEffect.CRITICAL_HIT_PITCH_MULTIPLIER - 0.01, "critical pitch %.3f should exceed base %.3f x multiplier %.2f" % [goblin.hurt_audio.pitch_scale, base_pitch, HitEffect.CRITICAL_HIT_PITCH_MULTIPLIER])
	assert(goblin.hurt_audio.volume_db >= base_volume + HitEffect.CRITICAL_HIT_VOLUME_BOOST_DB, "critical hit sound should be louder")
	assert(goblin.hurt_audio.playing, "critical hit should play the enemy hurt sound")
	var critical_dings: Array[AudioStreamPlayer2D] = _get_critical_dings()
	assert(critical_dings.size() == prior_ding_count + 1, "each critical hit should add one ding")
	var ding_player: AudioStreamPlayer2D = critical_dings.back()
	assert(ding_player.playing, "critical ding should play alongside the pitched hurt sound")
	assert(ding_player.stream == HitEffect.CRITICAL_DING_SOUND)
	assert(is_equal_approx(ding_player.volume_db, HitEffect.CRITICAL_DING_VOLUME_DB), "critical ding should be at 70% volume (-3.1 dB)")
	var blood_effects: Array[AnimatedSprite2D] = _get_blood_effects()
	assert(blood_effects.size() == prior_blood_count + 1, "critical sword hit should spawn one blood effect")
	var blood: AnimatedSprite2D = blood_effects[blood_effects.size() - 1]
	assert(blood.animation == &"splatter" and blood.is_playing(), "critical blood effect should play the splatter animation")
	for effect: AnimatedSprite2D in blood_effects:
		effect.queue_free()
	for ding: AudioStreamPlayer2D in critical_dings:
		ding.queue_free()
	goblin.queue_free()
	player.queue_free()
	await get_tree().process_frame

func test_spear_multi_target_critical_spawns_blood_on_each_enemy() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	var first_goblin: GoblinEnemy = GOBLIN_SCENE.instantiate() as GoblinEnemy
	var second_goblin: GoblinEnemy = GOBLIN_SCENE.instantiate() as GoblinEnemy
	player.auto_start = false
	add_child(player)
	add_child(first_goblin)
	add_child(second_goblin)
	await get_tree().process_frame
	player.set_physics_process(false)
	first_goblin.set_physics_process(false)
	second_goblin.set_physics_process(false)
	player.state = PlayerController.PlayerState.SPEAR_ATTACK
	player.animated_sprite.play(&"spearattack")
	player.animated_sprite.frame = 2
	player.call("_sync_collision_shape")
	first_goblin.global_position = player.attack_hitbox.global_position
	second_goblin.global_position = player.attack_hitbox.global_position
	var prior_blood_count: int = _get_blood_effects().size()
	var prior_ding_count: int = _get_critical_dings().size()
	var first_base_pitch: float = first_goblin.hurt_audio.pitch_scale
	var second_base_pitch: float = second_goblin.hurt_audio.pitch_scale
	var first_base_volume: float = first_goblin.hurt_audio.volume_db
	var second_base_volume: float = second_goblin.hurt_audio.volume_db
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	assert(player.call("_count_overlapping_attack_enemies") == 2, "spear should see both enemies for one impact")
	assert(player.is_attack_critical(), "spear hits on multiple overlapping enemies should be critical")
	assert(first_goblin.health < first_goblin.max_health and second_goblin.health < second_goblin.max_health, "both overlapping enemies should be struck by the spear")
	assert(first_goblin.hurt_audio.pitch_scale >= first_base_pitch * HitEffect.CRITICAL_HIT_PITCH_MULTIPLIER - 0.01 and second_goblin.hurt_audio.pitch_scale >= second_base_pitch * HitEffect.CRITICAL_HIT_PITCH_MULTIPLIER - 0.01, "spear pitches %.3f/%.3f should exceed bases %.3f/%.3f" % [first_goblin.hurt_audio.pitch_scale, second_goblin.hurt_audio.pitch_scale, first_base_pitch, second_base_pitch])
	assert(first_goblin.hurt_audio.volume_db >= first_base_volume + HitEffect.CRITICAL_HIT_VOLUME_BOOST_DB and second_goblin.hurt_audio.volume_db >= second_base_volume + HitEffect.CRITICAL_HIT_VOLUME_BOOST_DB, "each simultaneous spear target should get louder critical audio")
	var blood_effects: Array[AnimatedSprite2D] = _get_blood_effects()
	assert(blood_effects.size() >= prior_blood_count + 2, "each spear crit should spawn blood; before=%d after=%d" % [prior_blood_count, blood_effects.size()])
	var critical_dings: Array[AudioStreamPlayer2D] = _get_critical_dings()
	assert(critical_dings.size() == prior_ding_count + 2, "each spear target critical should get its own ding")
	for ding: AudioStreamPlayer2D in critical_dings:
		assert(ding.stream == HitEffect.CRITICAL_DING_SOUND and is_equal_approx(ding.volume_db, HitEffect.CRITICAL_DING_VOLUME_DB))
		ding.queue_free()
	for effect: AnimatedSprite2D in blood_effects:
		effect.queue_free()
	first_goblin.queue_free()
	second_goblin.queue_free()
	player.queue_free()
	await get_tree().process_frame

func _get_blood_effects() -> Array[AnimatedSprite2D]:
	var effects: Array[AnimatedSprite2D] = []
	for child: Node in get_children():
		var effect: AnimatedSprite2D = child as AnimatedSprite2D
		if effect != null and effect.sprite_frames.has_animation(&"splatter"):
			effects.append(effect)
	return effects

func _get_critical_dings() -> Array[AudioStreamPlayer2D]:
	var dings: Array[AudioStreamPlayer2D] = []
	for child: Node in get_children():
		if not child.is_in_group("critical_hit_ding"):
			continue
		var ding: AudioStreamPlayer2D = child as AudioStreamPlayer2D
		if ding != null:
			dings.append(ding)
	return dings
