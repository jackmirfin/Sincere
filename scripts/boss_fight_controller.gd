extends Node2D
class_name BossFightController

const BOSS_HEALTH_HUD_SCENE: PackedScene = preload("res://scenes/bosshealthhud.tscn")
const BOSS_MUSIC: AudioStream = preload("res://assets/sounds/boss1.mp3")

@export var camera_pan_to_wizard_duration: float = 1.0
@export var camera_return_duration: float = 0.45
@export var enemy_spawn_delay: float = 2.0

@onready var wizard: CaveEvilWizard = $evilwizard
@onready var start_area: Area2D = $bossfightstart
@onready var spawn_container: Node2D = $spawns_wizardteleports
@onready var wizard_teleport: Node2D = $spawns_wizardteleports/wizardteleport
@onready var end_gate: CaveGate = get_node("../rooms_gates/endgate") as CaveGate

var encounter_started: bool = false
var player: PlayerController = null
var boss_health_hud: BossHealthBar = null
var camera_return_finished: bool = false
var boss_resume_finished: bool = false
var boss_combat_started: bool = false
var cinematic_camera: Camera2D = null
var cinematic_follow_wizard: bool = false

func _ready() -> void:
	start_area.body_entered.connect(_on_start_area_body_entered)
	wizard.health_changed.connect(_on_wizard_health_changed)
	wizard.defeated.connect(_on_wizard_defeated)
	wizard.death_sequence_finished.connect(_on_wizard_death_sequence_finished)
	boss_health_hud = BOSS_HEALTH_HUD_SCENE.instantiate() as BossHealthBar
	add_child(boss_health_hud)
	wizard.set_encounter_dormant()

func _process(_delta: float) -> void:
	if cinematic_follow_wizard and is_instance_valid(cinematic_camera) and is_instance_valid(wizard):
		cinematic_camera.global_position = wizard.global_position + Vector2(0.0, -24.0)


func _on_start_area_body_entered(body: Node2D) -> void:
	if encounter_started:
		return
	var entered_player: PlayerController = body as PlayerController
	if entered_player == null:
		return
	encounter_started = true
	player = entered_player
	_run_intro_sequence.call_deferred()

func _run_intro_sequence() -> void:
	if player == null:
		return
	while is_instance_valid(player) and not player.is_on_floor():
		await get_tree().physics_frame
	if not is_instance_valid(player):
		return
	player.prepare_for_boss_cinematic()
	player.set_teleport_locked(true)
	var player_camera: Camera2D = player.get_node("Camera2D") as Camera2D
	cinematic_camera = Camera2D.new()
	cinematic_camera.name = "BossCinematicCamera"
	cinematic_camera.zoom = player_camera.zoom
	cinematic_camera.global_position = player_camera.get_screen_center_position()
	var camera_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	camera_parent.add_child(cinematic_camera)
	cinematic_camera.make_current()
	var camera_tween: Tween = create_tween()
	camera_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(cinematic_camera, "global_position", wizard.global_position + Vector2(0.0, -24.0), camera_pan_to_wizard_duration)
	await camera_tween.finished
	wizard.activate_for_intro()
	cinematic_follow_wizard = true
	wizard.cinematic_teleport_to(wizard_teleport.global_position)
	await wizard.intro_teleport_finished
	cinematic_camera.global_position = wizard.global_position + Vector2(0.0, -24.0)
	await get_tree().create_timer(0.2).timeout
	_play_boss_pause_resume()
	cinematic_follow_wizard = false
	var return_tween: Tween = create_tween()
	return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(cinematic_camera, "global_position", player.global_position + player_camera.position, camera_return_duration)
	await return_tween.finished
	player_camera.make_current()
	cinematic_camera.queue_free()
	cinematic_camera = null
	camera_return_finished = true
	_try_finish_boss_intro()

func _play_boss_pause_resume() -> void:
	var played: bool = player.play_menu_animation(&"pause", Callable(self, "_start_boss_resume"))
	if not played:
		_start_boss_resume()

func _start_boss_resume() -> void:
	var played: bool = player.play_menu_animation(&"resume", Callable(self, "_on_boss_resume_finished"), Callable(self, "_start_boss_music_and_fight"))
	if not played:
		_start_boss_music_and_fight()
		_on_boss_resume_finished()

func _start_boss_music_and_fight() -> void:
	if boss_combat_started:
		return
	boss_combat_started = true
	var current_scene: Node = get_tree().current_scene
	var music: AudioStreamPlayer = current_scene.get_node_or_null("BackgroundMusic") as AudioStreamPlayer if current_scene != null else null
	if music != null:
		music.stop()
		music.stream = BOSS_MUSIC
		music.stream_paused = false
		music.play()
		music.seek(0.0)
	var spawn_markers: Array[Node2D] = []
	for marker_name: StringName in [&"spawn1", &"spawn2", &"spawn3"]:
		var marker: Node2D = spawn_container.get_node(NodePath(marker_name)) as Node2D
		spawn_markers.append(marker)
	boss_health_hud.show_bar(wizard.max_health, wizard.health)
	_begin_fight_after_delay(spawn_markers)


func _begin_fight_after_delay(spawn_markers: Array[Node2D]) -> void:
	await get_tree().create_timer(enemy_spawn_delay).timeout
	if not is_instance_valid(wizard) or wizard.dead:
		return
	wizard.begin_fight(spawn_markers, wizard_teleport)


func _on_boss_resume_finished() -> void:
	player.finish_menu_resume()
	boss_resume_finished = true
	_try_finish_boss_intro()

func _try_finish_boss_intro() -> void:
	if not camera_return_finished or not boss_resume_finished:
		return
	player.set_teleport_locked(false)

func _on_wizard_health_changed(current_health: int, maximum_health: int) -> void:
	boss_health_hud.update_health(current_health, maximum_health)

func _on_wizard_defeated() -> void:
	boss_health_hud.hide_bar()

func _on_wizard_death_sequence_finished() -> void:
	end_gate.open_gate()
