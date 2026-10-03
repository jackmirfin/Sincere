extends AnimatedSprite2D
class_name AttackIndicator

@export var hitbox_frame: int = 11
@export var loop_until_removed: bool = false
var notified: bool = false

func _ready() -> void:
	frame_changed.connect(_on_frame_changed)
	animation_finished.connect(_on_animation_finished)
	play(&"attackindicator")

func _on_frame_changed() -> void:
	if not notified and frame == hitbox_frame:
		notified = true
		var owner_node: Node = get_parent()
		if owner_node != null and bool(owner_node.get("dead")):
			queue_free()
			return
		if owner_node != null and owner_node.has_method("attack_indicator_frame_reached"):
			owner_node.call("attack_indicator_frame_reached")

func _on_animation_finished() -> void:
	if loop_until_removed and is_instance_valid(get_parent()) and not bool(get_parent().get("dead")):
		frame = 0
		play(&"attackindicator")
		return
	queue_free()
