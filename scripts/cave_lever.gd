extends AnimatedSprite2D
class_name CaveLever

signal flipped

@export var interaction_radius: float = 44.0

var can_interact: bool = true
var flipping: bool = false
var flipped_state: bool = false
var player: PlayerController = null


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	var activation_area: Area2D = $ActivationArea
	activation_area.body_entered.connect(_on_activation_body_entered)
	activation_area.body_exited.connect(_on_activation_body_exited)
	activation_area.area_entered.connect(_on_activation_area_entered)
	play(&"unflipped")


func _physics_process(_delta: float) -> void:
	if not can_interact or not is_instance_valid(player):
		return
	if Input.is_action_just_pressed("interact"):
		flip()


func _on_activation_body_entered(body: Node2D) -> void:
	var entered_player: PlayerController = body as PlayerController
	if entered_player != null:
		player = entered_player


func _on_activation_body_exited(body: Node2D) -> void:
	if body == player:
		player = null


func _on_activation_area_entered(area: Area2D) -> void:
	if can_interact and area.is_in_group("player_attack_hitbox"):
		flip()


func flip() -> void:
	if not can_interact or flipping or flipped_state:
		return
	can_interact = false
	flipping = true
	play(&"flipping")


func _on_animation_finished() -> void:
	if not flipping or animation != &"flipping":
		return
	flipping = false
	flipped_state = true
	play(&"flipped")
	flipped.emit()

func reset_to_unflipped() -> void:
	flipping = false
	flipped_state = false
	can_interact = true
	play(&"unflipped")
