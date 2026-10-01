extends Area2D
class_name GoblinBomb

const EXPLOSION_SOUND: AudioStream = preload("res://assets/sounds/explosion.wav")
const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")

@export var fuse_time: float = 1.8
@export var explosion_radius: float = 48.0
@export var damage: int = 18

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var fuse_remaining: float = 0.0
var exploded: bool = false
var dead: bool = false
var landed: bool = false
var vertical_velocity: float = 0.0
var horizontal_velocity: float = 0.0
@export var bomb_gravity: float = 1250.0

func _ready() -> void:
	fuse_remaining = fuse_time
	body_entered.connect(_on_body_entered)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.play(&"bomb")
	_spawn_warning_indicator()

func _physics_process(delta: float) -> void:
	if exploded:
		return
	if not landed:
		var previous_position: Vector2 = global_position
		vertical_velocity += bomb_gravity * delta
		var next_position: Vector2 = global_position + Vector2(horizontal_velocity * delta, vertical_velocity * delta)
		var ray_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(previous_position, next_position, 1)
		var collision: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray_query)
		if collision.is_empty():
			global_position = next_position
		else:
			global_position = collision["position"] as Vector2
			landed = true
			vertical_velocity = 0.0

func _on_body_entered(_body: Node2D) -> void:
	pass

func _spawn_warning_indicator() -> void:
	var indicator: AttackIndicator = ATTACK_INDICATOR_SCENE.instantiate() as AttackIndicator
	indicator.position = Vector2(0.0, -24.0)
	indicator.z_index = 2
	add_child(indicator)

func _explode() -> void:
	if exploded:
		return
	exploded = true
	dead = true
	var audio: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	audio.stream = EXPLOSION_SOUND
	get_tree().root.add_child(audio)
	audio.global_position = global_position
	audio.finished.connect(audio.queue_free)
	audio.play()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = explosion_radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2 | 8
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query)
	var hit_nodes: Dictionary = {}
	for hit: Dictionary in hits:
		var target: Object = hit.get("collider") as Object
		if target == null or hit_nodes.has(target):
			continue
		hit_nodes[target] = true
		if target.has_method("receive_hit"):
			target.call("receive_hit", false)
		elif target.has_method("take_damage"):
			target.call("take_damage", damage, 2, signf((target as Node2D).global_position.x - global_position.x))
	queue_free()

func _on_frame_changed() -> void:
	if not exploded and animated_sprite.animation == &"bomb" and animated_sprite.frame == 12:
		_explode()

func _on_animation_finished() -> void:
	pass
