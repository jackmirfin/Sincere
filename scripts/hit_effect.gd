extends RefCounted
class_name HitEffect

const HIT_SCENE: PackedScene = preload("res://scenes/hitanimation.tscn")

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
