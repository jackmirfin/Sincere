extends Node
class_name TestCombatAttackAudio

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const SKELETON_SCENE: PackedScene = preload("res://scenes/skeleton.tscn")
const SMALL_SPIDER_SCENE: PackedScene = preload("res://scenes/smallspider.tscn")
const BIG_SPIDER_SCENE: PackedScene = preload("res://scenes/bigspider.tscn")
const FLYING_EYE_SCENE: PackedScene = preload("res://scenes/flyingeye.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://scenes/goblin.tscn")
const MUSHROOM_SCENE: PackedScene = preload("res://scenes/mushroom.tscn")
const SAMURAI_SCENE: PackedScene = preload("res://scenes/samurai.tscn")
const OGRE_SCENE: PackedScene = preload("res://scenes/orge.tscn")
const WIZARD_SCENE: PackedScene = preload("res://scenes/evilwizard.tscn")

func test_player_and_skeleton_use_their_swing_sounds_at_80_percent() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	var skeleton: SkeletonEnemy = SKELETON_SCENE.instantiate() as SkeletonEnemy
	skeleton.set_physics_process(false)
	add_child(skeleton)
	await get_tree().process_frame
	player._change_state(PlayerController.PlayerState.ATTACK1)
	assert(player.swing_audio.stream == PlayerController.PLAYER_SWING_SOUND)
	assert(is_equal_approx(player.swing_audio.volume_db, PlayerController.SWING_VOLUME_DB))
	assert(player.swing_audio.playing, "player swing audio did not start on attack")
	skeleton._change_state(SkeletonEnemy.EnemyState.ATTACK_WINDUP)
	skeleton._change_state(SkeletonEnemy.EnemyState.ATTACK_ACTIVE)
	assert(skeleton.swing_audio.stream == SkeletonEnemy.SKELETON_SWING_SOUND)
	assert(is_equal_approx(skeleton.swing_audio.volume_db, SkeletonEnemy.SWING_VOLUME_DB))
	assert(skeleton.swing_audio.playing, "skeleton sword swing audio did not start on its strike")
	player.queue_free()
	skeleton.queue_free()
	await get_tree().process_frame

func test_enemy_wooshes_have_distinct_pitches_with_small_spider_highest() -> void:
	var small_spider: SmallSpiderEnemy = SMALL_SPIDER_SCENE.instantiate() as SmallSpiderEnemy
	var big_spider: BigSpiderEnemy = BIG_SPIDER_SCENE.instantiate() as BigSpiderEnemy
	var flying_eye: FlyingEyeEnemy = FLYING_EYE_SCENE.instantiate() as FlyingEyeEnemy
	var goblin: GoblinEnemy = GOBLIN_SCENE.instantiate() as GoblinEnemy
	var mushroom: MushroomEnemy = MUSHROOM_SCENE.instantiate() as MushroomEnemy
	var samurai: SamuraiEnemy = SAMURAI_SCENE.instantiate() as SamuraiEnemy
	var ogre: OgreEnemy = OGRE_SCENE.instantiate() as OgreEnemy
	var wizard: EvilWizardEnemy = WIZARD_SCENE.instantiate() as EvilWizardEnemy
	var enemies: Array[Node2D] = [small_spider, big_spider, flying_eye, goblin, mushroom, samurai, ogre, wizard]
	for enemy: Node2D in enemies:
		enemy.set_physics_process(false)
		add_child(enemy)
	await get_tree().process_frame
	var pitches: Array[float] = [
		small_spider.attack_woosh_audio.pitch_scale,
		big_spider.attack_woosh_audio.pitch_scale,
		flying_eye.attack_woosh_audio.pitch_scale,
		goblin.attack_woosh_audio.pitch_scale,
		mushroom.attack_woosh_audio.pitch_scale,
		samurai.attack_woosh_audio.pitch_scale,
		ogre.attack_woosh_audio.pitch_scale,
		wizard.attack_woosh_audio.pitch_scale
	]
	for enemy: Node2D in enemies:
		var woosh: AudioStreamPlayer2D = enemy.get_node("AttackWooshSound") as AudioStreamPlayer2D
		assert(woosh.stream == EnemyAttackAudio.WOOSH_SOUND)
		assert(is_equal_approx(woosh.volume_db, EnemyAttackAudio.WOOSH_VOLUME_DB))
	for pitch_index: int in range(pitches.size() - 1):
		assert(pitches[pitch_index] > pitches[pitch_index + 1], "enemy woosh pitches must descend from small spiders")
	small_spider._change_state(SmallSpiderEnemy.EnemyState.ATTACK)
	big_spider._change_state(BigSpiderEnemy.EnemyState.ATTACK)
	flying_eye._change_state(FlyingEyeEnemy.EnemyState.ATTACK_ACTIVE)
	goblin._change_state(GoblinEnemy.EnemyState.ATTACK_ACTIVE)
	mushroom._change_state(MushroomEnemy.EnemyState.ATTACK_ACTIVE)
	samurai._change_state(SamuraiEnemy.EnemyState.ATTACK_ACTIVE)
	ogre._change_state(OgreEnemy.OgreState.ATTACK)
	wizard._start_melee()
	for enemy: Node2D in enemies:
		var woosh: AudioStreamPlayer2D = enemy.get_node("AttackWooshSound") as AudioStreamPlayer2D
		assert(woosh.playing, "%s did not play its attack woosh" % enemy.name)
	for enemy: Node2D in enemies:
		enemy.queue_free()
	await get_tree().process_frame
