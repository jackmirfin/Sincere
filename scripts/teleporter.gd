extends Node2D
class_name Teleporter

const INTERACT_PROMPT_SCENE: PackedScene = preload("res://scenes/interactprompt.tscn")

@export var receiver_path: NodePath
@export var interaction_action: StringName = &"interact"
@export var teleport_frame: int = 9
@export var arrival_start_frame: int = 2
@export var show_interact_prompt: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea

var player: PlayerController = null
var teleporting: bool = false
var did_teleport: bool = false
var prompt_used: bool = false
var interact_prompt: Label = null
var arrival_effect: AnimatedSprite2D = null

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(&"idle")
	if should_show_interact_prompt():
		show_interact_prompt = true
		interact_prompt = INTERACT_PROMPT_SCENE.instantiate() as Label
		interact_prompt.position = Vector2(-12.0, -52.0)
		add_child(interact_prompt)

func should_show_interact_prompt() -> bool:
	if show_interact_prompt:
		return true
	var scene_root: Node = get_parent()
	return name == &"teleporter" and scene_root != null and scene_root.scene_file_path == "res://scenes/world.tscn"

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	if not teleporting and not interaction_area.overlaps_body(player):
		player = null
		return
	if teleporting:
		return
	if Input.is_action_just_pressed(interaction_action):
		_begin_teleport()

func _on_body_entered(body: Node2D) -> void:
	var entered_player: PlayerController = body as PlayerController
	if entered_player != null:
		player = entered_player

func _on_body_exited(body: Node2D) -> void:
	if body == player and not teleporting:
		player = null

func _begin_teleport() -> void:
	if player == null:
		return
	teleporting = true
	did_teleport = false
	dismiss_interact_prompt()
	player.set_teleport_locked(true)
	animated_sprite.play(&"teleport")

func dismiss_interact_prompt() -> void:
	if prompt_used:
		return
	prompt_used = true
	show_interact_prompt = false
	if is_instance_valid(interact_prompt):
		interact_prompt.hide()

func _on_frame_changed() -> void:
	if not teleporting or did_teleport or animated_sprite.animation != &"teleport":
		return
	if animated_sprite.frame == teleport_frame:
		var receiver: Node2D = _find_receiver()
		if receiver != null and player != null:
			_complete_player_teleport(receiver)

func _complete_player_teleport(receiver: Node2D) -> void:
	if player == null:
		return
	player.global_position = receiver.global_position
	did_teleport = true
	_play_arrival_effect(player.global_position)


func _play_arrival_effect(effect_position: Vector2) -> void:
	if is_instance_valid(arrival_effect):
		arrival_effect.queue_free()
	arrival_effect = AnimatedSprite2D.new()
	arrival_effect.name = "TeleportArrivalEffect"
	arrival_effect.sprite_frames = animated_sprite.sprite_frames
	arrival_effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arrival_effect.z_index = player.z_index + 10 if player != null else 10
	var effect_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if effect_parent == null:
		effect_parent = self
	effect_parent.add_child(arrival_effect)
	arrival_effect.global_position = effect_position
	arrival_effect.animation_finished.connect(_on_arrival_effect_finished.bind(arrival_effect), CONNECT_ONE_SHOT)
	arrival_effect.play(&"teleportappear")
	var frame_count: int = arrival_effect.sprite_frames.get_frame_count(&"teleportappear")
	arrival_effect.set_frame_and_progress(clampi(arrival_start_frame, 0, maxi(0, frame_count - 1)), 0.0)


func _on_arrival_effect_finished(effect: AnimatedSprite2D) -> void:
	if not is_instance_valid(effect):
		return
	if arrival_effect == effect:
		arrival_effect = null
	effect.queue_free()


func _on_animation_finished() -> void:
	if animated_sprite.animation != &"teleport":
		return
	animated_sprite.play(&"idle")
	teleporting = false
	if player != null:
		player.set_teleport_locked(false)
		if did_teleport:
			player = null

func _find_receiver() -> Node2D:
	if not receiver_path.is_empty():
		var receiver: Node2D = get_node_or_null(receiver_path) as Node2D
		if receiver != null:
			return receiver
	var receivers: Array[Node] = get_tree().get_nodes_in_group("teleport_receiver")
	if receivers.size() > 0:
		return receivers[0] as Node2D
	return null
