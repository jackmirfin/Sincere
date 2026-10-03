extends CharacterBody2D
class_name CaveEvilWizard

signal intro_teleport_finished
signal health_changed(current_health: int, maximum_health: int)
signal defeated
signal death_sequence_finished

enum WizardState { IDLE, RECOVER, MELEE, CAST, TELEPORT_OUT, TELEPORT_IN, HURT, DEAD }
enum ScriptedAction { THUNDER, SUMMON, HEAL }
enum FightPhase { DORMANT, WAVE_ONE, MELEE_ONE, WAVE_TWO, MELEE_TWO, FINAL_WAVE, FINAL_MELEE, DEAD }

const SPELL_SCENE: PackedScene = preload("res://scenes/evilwizardspell.tscn")
const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")
const ENEMY_HURT_SOUND: AudioStream = preload("res://assets/sounds/enemyhurt.mp3")
const FLYING_EYE_SCENE: PackedScene = preload("res://scenes/flyingeye.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://scenes/goblin.tscn")
const MUSHROOM_SCENE: PackedScene = preload("res://scenes/mushroom.tscn")
const SKELETON_SCENE: PackedScene = preload("res://scenes/skeleton.tscn")
const LAB_NOTES_BOOK_SCENE: PackedScene = preload("res://scenes/labnotesbook.tscn")
const GRAVITY: float = 1250.0
const MELEE_IMPACT_FRAME: int = 5
const ATTACK_WOOSH_PITCH: float = 0.70
const CAST_TRIGGER_FRAME: int = 4

@export var max_health: int = 180
@export var melee_range: float = 76.0
@export var chase_speed: float = 92.0
@export var action_delay: float = 0.9
@export var melee_recovery: float = 0.48
@export var thunder_spacing: float = 58.0
@export var final_thunder_interval: float = 4.0
@export var summon_spawn_interval: float = 0.45
@export var death_slowmo_scale: float = 0.25
@export var coin_drop_multiplier: int = 14

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_shape: CollisionShape2D = $WeaponHitbox/CollisionShape2D

var state: WizardState = WizardState.IDLE
var phase: FightPhase = FightPhase.DORMANT
var current_action: ScriptedAction = ScriptedAction.THUNDER
var player: CharacterBody2D = null
var health: int = 0
var facing: int = -1
var action_time: float = 0.0
var parry_stun_time: float = 0.0
var cast_triggered: bool = false
var melee_impact_reached: bool = false
var dead: bool = false
var encounter_active: bool = false
var cinematic_teleport: bool = false
var teleport_destination: Vector2 = Vector2.ZERO
var spawn_markers: Array[Node2D] = []
var wizard_teleport_marker: Node2D = null
var summoned_enemies: Array[Node2D] = []
var pending_summon_count: int = 0
var pending_summon_pool: Array[PackedScene] = []
var pending_minimum_skeletons: int = 0
var shield_active: bool = false
var final_thunder_time: float = 0.0
var drop_launch_time: float = 0.0
var heal_then_drop: bool = false
var struck_attack_ids: Dictionary = {}
var hit_effect_index: int = 0
var spell_overlay: EvilWizardSpellEffect = null
var hurt_audio: AudioStreamPlayer2D = null
var attack_woosh_audio: AudioStreamPlayer2D = null
var lab_notes_book: LabNotesBook = null

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	floor_snap_length = 4.0
	weapon_shape.disabled = true
	weapon_hitbox.monitoring = false
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	animated_sprite.frame_changed.connect(_on_body_frame_changed)
	animated_sprite.animation_finished.connect(_on_body_animation_finished)
	spell_overlay = SPELL_SCENE.instantiate() as EvilWizardSpellEffect
	spell_overlay.position = Vector2(0.0, -12.0)
	spell_overlay.z_index = 2
	spell_overlay.effect_finished.connect(_on_spell_effect_finished)
	add_child(spell_overlay)
	hurt_audio = AudioStreamPlayer2D.new()
	hurt_audio.stream = ENEMY_HURT_SOUND
	hurt_audio.pitch_scale = 1.02
	add_child(hurt_audio)
	attack_woosh_audio = EnemyAttackAudio.create_player(self, ATTACK_WOOSH_PITCH)
	_set_animation(&"idle", true)

func set_encounter_dormant() -> void:
	encounter_active = false
	phase = FightPhase.DORMANT
	visible = false
	velocity = Vector2.ZERO
	body_collision.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)
	_set_weapon_active(false)

func activate_for_intro() -> void:
	visible = true
	animated_sprite.visible = true
	velocity = Vector2.ZERO
	_set_animation(&"idle", true)

func cinematic_teleport_to(destination: Vector2) -> void:
	cinematic_teleport = true
	teleport_destination = destination
	state = WizardState.TELEPORT_OUT
	animated_sprite.visible = true
	spell_overlay.scale = Vector2.ONE
	spell_overlay.play_effect(&"teleport")

func begin_fight(markers: Array[Node2D], top_marker: Node2D) -> void:
	spawn_markers = markers
	wizard_teleport_marker = top_marker
	encounter_active = true
	body_collision.set_deferred("disabled", false)
	hurtbox.set_deferred("monitoring", true)
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_begin_wave(FightPhase.WAVE_ONE, 4, false, 0)

func _physics_process(delta: float) -> void:
	if dead or not encounter_active:
		return
	if parry_stun_time > 0.0:
		parry_stun_time = maxf(0.0, parry_stun_time - delta)
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		move_and_slide()
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_cleanup_summoned_enemies()
	_check_phase_transitions()
	_apply_gravity(delta)
	if phase == FightPhase.FINAL_MELEE:
		final_thunder_time = maxf(0.0, final_thunder_time - delta)
		if final_thunder_time <= 0.0:
			_spawn_thunder_barrage()
			final_thunder_time = final_thunder_interval
	if drop_launch_time > 0.0:
		drop_launch_time = maxf(0.0, drop_launch_time - delta)
	elif state == WizardState.IDLE and phase in [FightPhase.MELEE_ONE, FightPhase.MELEE_TWO, FightPhase.FINAL_MELEE]:
		_process_melee_chase()
	if state == WizardState.RECOVER:
		action_time = maxf(0.0, action_time - delta)
		if action_time <= 0.0:
			if phase in [FightPhase.WAVE_ONE, FightPhase.WAVE_TWO]:
				_start_cast(ScriptedAction.THUNDER)
			else:
				_change_state(WizardState.IDLE)
	if player != null and state not in [WizardState.TELEPORT_OUT, WizardState.TELEPORT_IN]:
		facing = 1 if player.global_position.x > global_position.x else -1
		animated_sprite.flip_h = facing < 0
	move_and_slide()

func _process_melee_chase() -> void:
	if player == null:
		velocity.x = 0.0
		return
	var horizontal_distance: float = absf(player.global_position.x - global_position.x)
	if horizontal_distance <= melee_range and absf(player.global_position.y - global_position.y) <= 70.0:
		velocity.x = 0.0
		_start_melee()
		return
	var direction: float = signf(player.global_position.x - global_position.x)
	velocity.x = direction * chase_speed
	_set_animation(&"walk" if animated_sprite.sprite_frames.has_animation(&"walk") else &"idle")

func _check_phase_transitions() -> void:
	if phase == FightPhase.WAVE_ONE and pending_summon_count == 0 and (_living_summon_count() == 0 or health <= int(max_health * 0.75)):
		_enter_melee_phase(FightPhase.MELEE_ONE, true)
	elif phase == FightPhase.MELEE_ONE and health <= int(max_health * 0.5):
		_begin_wave(FightPhase.WAVE_TWO, 6, true, 2)
	elif phase == FightPhase.WAVE_TWO and _living_summon_count() == 0 and pending_summon_count == 0:
		_set_shield_active(false)
		_enter_melee_phase(FightPhase.MELEE_TWO, false)
	elif phase == FightPhase.MELEE_TWO and health <= int(max_health * 0.25):
		_begin_wave(FightPhase.FINAL_WAVE, 8, true, 0)

func _begin_wave(next_phase: FightPhase, count: int, use_full_pool: bool, minimum_skeletons: int) -> void:
	phase = next_phase
	visible = true
	animated_sprite.visible = true
	velocity = Vector2.ZERO
	_set_weapon_active(false)
	_set_shield_active(false)
	pending_summon_count = count
	pending_minimum_skeletons = minimum_skeletons
	pending_summon_pool = _full_enemy_pool() if use_full_pool else _basic_enemy_pool()
	if wizard_teleport_marker != null and next_phase != FightPhase.WAVE_ONE:
		teleport_destination = wizard_teleport_marker.global_position
		state = WizardState.TELEPORT_OUT
		spell_overlay.scale = Vector2.ONE
		spell_overlay.play_effect(&"teleport")
	else:
		_start_cast(ScriptedAction.SUMMON)

func _enter_melee_phase(next_phase: FightPhase, leap_from_platform: bool) -> void:
	phase = next_phase
	_set_shield_active(false)
	spell_overlay.stop_effect()
	_change_state(WizardState.IDLE)
	_set_animation(&"idle", true)
	if leap_from_platform and player != null:
		var direction: float = signf(player.global_position.x - global_position.x)
		velocity = Vector2(direction * 175.0, -125.0)
		drop_launch_time = 0.6
	else:
		_drop_to_lower_arena()

func _drop_to_lower_arena() -> void:
	if spawn_markers.is_empty():
		return
	var target: Node2D = spawn_markers[randi() % spawn_markers.size()]
	global_position = target.global_position
	velocity = Vector2.ZERO

func _start_melee() -> void:
	attack_woosh_audio.play()
	_change_state(WizardState.MELEE)
	melee_impact_reached = false
	struck_attack_ids.clear()
	_spawn_melee_indicator()
	_set_animation(&"attack", true)

func _start_cast(action: ScriptedAction) -> void:
	attack_woosh_audio.play()
	current_action = action
	cast_triggered = false
	velocity.x = 0.0
	_change_state(WizardState.CAST)
	_set_animation(&"cast", true)

func _on_body_frame_changed() -> void:
	if state == WizardState.MELEE:
		if animated_sprite.frame >= MELEE_IMPACT_FRAME and not melee_impact_reached:
			melee_impact_reached = true
			_set_weapon_active(true)
		elif melee_impact_reached and animated_sprite.frame > MELEE_IMPACT_FRAME:
			_set_weapon_active(false)
	elif state == WizardState.CAST and animated_sprite.frame >= CAST_TRIGGER_FRAME and not cast_triggered:
		_trigger_cast_action()

func _trigger_cast_action() -> void:
	cast_triggered = true
	match current_action:
		ScriptedAction.THUNDER:
			_spawn_thunder_barrage()
		ScriptedAction.SUMMON:
			spell_overlay.scale = Vector2(1.2, 1.2)
			spell_overlay.play_effect(&"summon")
			_spawn_pending_wave()
		ScriptedAction.HEAL:
			health = maxi(health, int(max_health * 0.5))
			health_changed.emit(health, max_health)
			spell_overlay.scale = Vector2(1.08, 1.08)
			spell_overlay.play_effect(&"heal")

func _on_body_animation_finished() -> void:
	if dead:
		animated_sprite.pause()
		return
	if state == WizardState.MELEE:
		_set_weapon_active(false)
		_enter_recovery(melee_recovery)
	elif state == WizardState.CAST:
		if not cast_triggered:
			_trigger_cast_action()
		if current_action == ScriptedAction.THUNDER:
			_enter_recovery()
		elif current_action == ScriptedAction.HEAL:
			if heal_then_drop:
				heal_then_drop = false
				phase = FightPhase.FINAL_MELEE
				_drop_to_lower_arena()
				final_thunder_time = final_thunder_interval
				_change_state(WizardState.IDLE)
			else:
				_enter_recovery()
	elif state == WizardState.HURT:
		_change_state(WizardState.IDLE)

func _complete_teleport_out() -> void:
	global_position = teleport_destination
	visible = true
	animated_sprite.visible = true
	state = WizardState.TELEPORT_IN
	if spell_overlay != null:
		spell_overlay.scale = Vector2.ONE
		spell_overlay.play_effect(&"teleportappear")


func _complete_teleport_in() -> void:
	visible = true
	animated_sprite.visible = true
	state = WizardState.IDLE
	if cinematic_teleport:
		cinematic_teleport = false
		intro_teleport_finished.emit()
	elif pending_summon_count > 0:
		_start_cast(ScriptedAction.SUMMON)


func _on_spell_effect_finished(animation_name: StringName) -> void:
	if dead:
		return
	if animation_name == &"teleport" and state == WizardState.TELEPORT_OUT:
		_complete_teleport_out()
	elif animation_name == &"teleportappear" and state == WizardState.TELEPORT_IN:
		_complete_teleport_in()
	elif animation_name == &"summon" and state == WizardState.CAST and current_action == ScriptedAction.SUMMON:
		if phase == FightPhase.WAVE_TWO:
			_set_shield_active(true)
			_enter_recovery(0.45)
		elif phase == FightPhase.FINAL_WAVE:
			heal_then_drop = true
			_start_cast(ScriptedAction.HEAL)
		else:
			_enter_recovery(0.45)

func _spawn_pending_wave() -> void:
	if pending_summon_count <= 0 or spawn_markers.is_empty() or pending_summon_pool.is_empty():
		return
	var scenes_to_spawn: Array[PackedScene] = []
	for _index: int in range(mini(pending_minimum_skeletons, pending_summon_count)):
		scenes_to_spawn.append(SKELETON_SCENE)
	while scenes_to_spawn.size() < pending_summon_count:
		scenes_to_spawn.append(pending_summon_pool[randi() % pending_summon_pool.size()])
	scenes_to_spawn.shuffle()
	pending_summon_pool.clear()
	var total: int = scenes_to_spawn.size()
	var marker_index: int = randi() % spawn_markers.size()
	for index: int in range(total):
		if dead or not encounter_active:
			pending_summon_count = 0
			pending_minimum_skeletons = 0
			return
		var marker: Node2D = spawn_markers[marker_index % spawn_markers.size()]
		marker_index += 1
		var enemy_scene: PackedScene = scenes_to_spawn[index]
		var enemy: Node2D = enemy_scene.instantiate() as Node2D
		get_parent().add_child(enemy)
		enemy.global_position = marker.global_position + Vector2(randf_range(-10.0, 10.0), -28.0 if enemy_scene == FLYING_EYE_SCENE else 0.0)
		_spawn_summon_effect(marker.global_position)
		enemy.add_to_group("wizard_summon")
		summoned_enemies.append(enemy)
		pending_summon_count = maxi(0, pending_summon_count - 1)
		if index < total - 1:
			await get_tree().create_timer(summon_spawn_interval).timeout
	pending_summon_count = 0
	pending_minimum_skeletons = 0

func _spawn_summon_effect(at_position: Vector2) -> void:
	var effect: EvilWizardSpellEffect = SPELL_SCENE.instantiate() as EvilWizardSpellEffect
	get_parent().add_child(effect)
	effect.global_position = at_position + Vector2(0.0, -12.0)
	effect.play_effect(&"summon", true)

func _basic_enemy_pool() -> Array[PackedScene]:
	return [FLYING_EYE_SCENE, GOBLIN_SCENE, MUSHROOM_SCENE]

func _full_enemy_pool() -> Array[PackedScene]:
	return [FLYING_EYE_SCENE, GOBLIN_SCENE, MUSHROOM_SCENE, SKELETON_SCENE]

func _cleanup_summoned_enemies() -> void:
	for index: int in range(summoned_enemies.size() - 1, -1, -1):
		var enemy: Node2D = summoned_enemies[index]
		if not is_instance_valid(enemy) or bool(enemy.get("dead")):
			summoned_enemies.remove_at(index)

func _living_summon_count() -> int:
	return summoned_enemies.size()

func _set_shield_active(active: bool) -> void:
	shield_active = active
	if active:
		spell_overlay.scale = Vector2(1.25, 1.25)
		spell_overlay.play_effect(&"shield")
	elif spell_overlay.animation == &"shield":
		spell_overlay.stop_effect()

func _spawn_thunder_barrage() -> void:
	if player == null:
		return
	var offsets: Array[float] = [-thunder_spacing, 0.0, thunder_spacing]
	for offset: float in offsets:
		var target_x: float = player.global_position.x + offset
		var floor_point: Vector2 = _floor_point_at(target_x, player.global_position.y)
		var warning: EvilWizardStrikeWarning = EvilWizardStrikeWarning.new()
		get_parent().add_child(warning)
		warning.global_position = floor_point
		warning.setup(self)

func _floor_point_at(target_x: float, reference_y: float) -> Vector2:
	var from: Vector2 = Vector2(target_x, reference_y - 180.0)
	var to: Vector2 = Vector2(target_x, reference_y + 320.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = [self]
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return result.get("position", Vector2(target_x, reference_y + 43.0)) as Vector2

func _spawn_melee_indicator() -> void:
	var indicator: AnimatedSprite2D = ATTACK_INDICATOR_SCENE.instantiate() as AnimatedSprite2D
	indicator.position = Vector2(0.0, -58.0)
	indicator.speed_scale = 1.45
	add_child(indicator)

func attack_indicator_frame_reached() -> void:
	pass

func _set_weapon_active(active: bool) -> void:
	weapon_shape.set_deferred("disabled", not active)
	weapon_hitbox.set_deferred("monitoring", active)
	weapon_hitbox.position = Vector2(43.0 * facing, 10.0)
	weapon_shape.position.x = absf(weapon_shape.position.x) * float(facing)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or shield_active or not encounter_active or not area.is_in_group("player_attack_hitbox"):
		return
	var player_attack_id: int = int(area.get_meta("attack_id", -1))
	if player_attack_id < 0 or struck_attack_ids.has(player_attack_id):
		return
	struck_attack_ids[player_attack_id] = true
	var attacker: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var attacker_position: Vector2 = attacker.global_position if attacker != null else global_position
	var attack_level: int = int(attacker.call("get_attack_level")) if attacker != null and attacker.has_method("get_attack_level") else 1
	HitEffect.spawn_hit(get_parent(), global_position + Vector2(0.0, -22.0), attacker_position, hit_effect_index)
	hit_effect_index = posmod(hit_effect_index + 1, 3)
	var damage: int = int(attacker.call("get_attack_damage")) if attacker != null and attacker.has_method("get_attack_damage") else (10 if attack_level == 1 else 20)
	take_damage(damage)

func stun_from_parry(duration: float) -> void:
	if dead or shield_active or not encounter_active:
		return
	parry_stun_time = maxf(parry_stun_time, duration)
	_set_weapon_active(false)
	spell_overlay.stop_effect()
	_change_state(WizardState.HURT)
	_set_animation(&"hurt", true)

func take_damage(amount: int, _attack_level: int = 1, _direction: float = 0.0) -> void:
	if dead or shield_active or not encounter_active:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	hurt_audio.play()
	_set_weapon_active(false)
	if health <= 0:
		_die()
	elif state not in [WizardState.CAST, WizardState.TELEPORT_OUT, WizardState.TELEPORT_IN]:
		_change_state(WizardState.HURT)
		_set_animation(&"hurt", true)

func _die() -> void:
	dead = true
	defeated.emit()
	phase = FightPhase.DEAD
	state = WizardState.DEAD
	velocity = Vector2.ZERO
	_set_weapon_active(false)
	_set_shield_active(false)
	spell_overlay.stop_effect()
	hurtbox.set_deferred("monitoring", false)
	body_collision.set_deferred("disabled", true)
	_set_animation(&"death", true)
	_drop_death_coins()
	_drop_lab_notes_book()
	_run_death_sequence()


func _drop_death_coins() -> void:
	# A normal enemy drops 4-5 coins; the boss drops coin_drop_multiplier times that.
	var manager: Node = get_node_or_null("/root/CoinDropManager")
	if manager != null and manager.has_method("drop_at"):
		manager.call("drop_at", get_parent(), global_position, {
			"drop_chance": 1.0,
			"min_coins": 4 * coin_drop_multiplier,
			"max_coins": 5 * coin_drop_multiplier,
			"min_types": 2,
			"max_types": 3,
			"value_multiplier": 1.5,
		})


func _drop_lab_notes_book() -> void:
	if lab_notes_book != null or get_parent() == null:
		return
	lab_notes_book = LAB_NOTES_BOOK_SCENE.instantiate() as LabNotesBook
	lab_notes_book.name = "LabNotesBook"
	get_parent().add_child(lab_notes_book)
	lab_notes_book.global_position = global_position + Vector2(18.0, -8.0)


func _run_death_sequence() -> void:
	Engine.time_scale = death_slowmo_scale
	_despawn_summons()
	if animated_sprite.animation == &"death" and animated_sprite.is_playing():
		await animated_sprite.animation_finished
	Engine.time_scale = 1.0
	death_sequence_finished.emit()


func _despawn_summons() -> void:
	var summons: Array[Node] = get_tree().get_nodes_in_group("wizard_summon")
	for node: Node in summons:
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		_spawn_summon_effect(enemy.global_position)
		enemy.remove_from_group("wizard_summon")
		enemy.queue_free()
	summoned_enemies.clear()

func _enter_recovery(duration: float = -1.0) -> void:
	_change_state(WizardState.RECOVER)
	action_time = action_delay if duration < 0.0 else duration
	_set_animation(&"idle", true)

func _change_state(next_state: WizardState) -> void:
	state = next_state
	if next_state != WizardState.MELEE:
		_set_weapon_active(false)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _set_animation(animation_name: StringName, restart: bool = false) -> void:
	if animated_sprite.sprite_frames.has_animation(animation_name) and (restart or animated_sprite.animation != animation_name):
		animated_sprite.play(animation_name)
