extends RefCounted
class_name HitEffect

const HIT_SCENE: PackedScene = preload("res://scenes/hitanimation.tscn")
const BLOOD_SCENE: PackedScene = preload("res://scenes/blood.tscn")
const CRITICAL_HIT_PITCH_MULTIPLIER: float = 1.5
const CRITICAL_HIT_VOLUME_BOOST_DB: float = 4.0
const CRITICAL_DING_SOUND: AudioStream = preload("res://assets/sounds/ding.mp3")
const CRITICAL_DING_VOLUME_DB: float = -3.1
const CRITICAL_BLOOD_SCALE: Vector2 = Vector2(0.5, 0.5)
const CRITICAL_BLOOD_OFFSET: Vector2 = Vector2(0.0, -12.0)
const BASE_HURT_PITCH_META: StringName = &"base_hurt_pitch"
const BASE_HURT_VOLUME_META: StringName = &"base_hurt_volume"
const HURT_PITCH_RESTORE_TOKEN_META: StringName = &"hurt_pitch_restore_token"
const CRITICAL_HURT_PITCH_DURATION: float = 0.35

static func spawn_hit(parent: Node, target_position: Vector2, attacker_position: Vector2, hit_index: int) -> void:
	var animation_name: StringName = &"hit1"
	match posmod(hit_index, 3):
		1:
			animation_name = &"hit2"
		2:
			animation_name = &"hit3"
	var attacking_from_right: bool = attacker_position.x > target_position.x
	var flip_h: bool = animation_name != &"hit1" if attacking_from_right else animation_name == &"hit1"
	var side: float = 1.0 if attacking_from_right else -1.0
	spawn(parent, target_position + Vector2(side * 20.0, -28.0), animation_name, flip_h)

static func apply_attack_damage(target: Node2D, attacker: Node, damage_arguments: Array, scale_damage_with_player: bool = true) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if attacker != null and attacker.has_method("is_spear_hit_active") and bool(attacker.call("is_spear_hit_active")):
		attacker.call("queue_spear_attack_damage", target, damage_arguments, scale_damage_with_player)
		return false
	var critical: bool = false
	if attacker != null and attacker.has_method("is_attack_critical_for"):
		critical = bool(attacker.call("is_attack_critical_for", target))
	elif attacker != null and attacker.has_method("is_attack_critical"):
		critical = bool(attacker.call("is_attack_critical"))
	if scale_damage_with_player and attacker != null and attacker.has_method("get_attack_damage_for_target") and not damage_arguments.is_empty():
		damage_arguments[0] = int(attacker.call("get_attack_damage_for_target", target))
	return apply_resolved_attack_damage(target, attacker, damage_arguments, critical)

static func apply_resolved_attack_damage(target: Node2D, attacker: Node, damage_arguments: Array, critical: bool) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var hurt_audio: AudioStreamPlayer2D = target.get("hurt_audio") as AudioStreamPlayer2D
	if hurt_audio != null:
		var base_pitch: float = float(target.get_meta(BASE_HURT_PITCH_META, hurt_audio.pitch_scale))
		var base_volume: float = float(target.get_meta(BASE_HURT_VOLUME_META, hurt_audio.volume_db))
		target.set_meta(BASE_HURT_PITCH_META, base_pitch)
		target.set_meta(BASE_HURT_VOLUME_META, base_volume)
		var restore_token: int = int(target.get_meta(HURT_PITCH_RESTORE_TOKEN_META, 0)) + 1
		target.set_meta(HURT_PITCH_RESTORE_TOKEN_META, restore_token)
		hurt_audio.pitch_scale = base_pitch * CRITICAL_HIT_PITCH_MULTIPLIER if critical else base_pitch
		hurt_audio.volume_db = base_volume + CRITICAL_HIT_VOLUME_BOOST_DB if critical else base_volume
		if critical:
			var restore_timer: SceneTreeTimer = target.get_tree().create_timer(CRITICAL_HURT_PITCH_DURATION)
			restore_timer.timeout.connect(func() -> void:
				if is_instance_valid(target) and is_instance_valid(hurt_audio) and int(target.get_meta(HURT_PITCH_RESTORE_TOKEN_META, -1)) == restore_token:
					hurt_audio.pitch_scale = base_pitch
					hurt_audio.volume_db = base_volume
			, CONNECT_ONE_SHOT)
	if critical:
		_play_critical_ding(target)
		_spawn_critical_blood(target)
	target.callv("take_damage", damage_arguments)
	return critical

static func _play_critical_ding(target: Node2D) -> void:
	var tree: SceneTree = target.get_tree()
	if tree == null:
		return
	var audio_parent: Node = target.get_parent()
	if audio_parent == null:
		audio_parent = tree.root
	var ding_player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	ding_player.stream = CRITICAL_DING_SOUND
	ding_player.volume_db = CRITICAL_DING_VOLUME_DB
	ding_player.add_to_group("critical_hit_ding")
	audio_parent.add_child(ding_player)
	ding_player.global_position = target.global_position
	ding_player.finished.connect(ding_player.queue_free, CONNECT_ONE_SHOT)
	ding_player.play()

static func _spawn_critical_blood(target: Node2D) -> void:
	var parent: Node = target.get_parent()
	if parent == null:
		return
	var blood: AnimatedSprite2D = BLOOD_SCENE.instantiate() as AnimatedSprite2D
	if blood == null:
		return
	parent.add_child(blood)
	blood.global_position = target.global_position + CRITICAL_BLOOD_OFFSET
	blood.z_index = target.z_index + 1
	blood.scale = CRITICAL_BLOOD_SCALE
	blood.add_to_group("critical_blood_effect")
	blood.animation_finished.connect(blood.queue_free, CONNECT_ONE_SHOT)
	blood.stop()
	blood.animation = &"splatter"
	blood.frame = 0
	blood.frame_progress = 0.0
	blood.play(&"splatter")

static func spawn_shield(parent: Node, target_position: Vector2, attacker_position: Vector2) -> void:
	var attacking_from_left: bool = attacker_position.x < target_position.x
	var side: float = -1.0 if attacking_from_left else 1.0
	spawn(parent, target_position + Vector2(side * 20.0, -28.0), &"shield", attacking_from_left)

static func spawn(parent: Node, position: Vector2, animation_name: StringName, flip_h: bool) -> void:
	if parent == null:
		return
	var effect: AnimatedSprite2D = HIT_SCENE.instantiate() as AnimatedSprite2D
	parent.add_child(effect)
	effect.global_position = position
	effect.flip_h = flip_h
	effect.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	effect.play(animation_name)
