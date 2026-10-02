extends Node
class_name TestTeleporter

const TELEPORTER_SCENE: PackedScene = preload("res://scenes/teleport.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")


func test_successful_teleport_clears_origin_teleporter_reference() -> void:
	var teleporter: Teleporter = TELEPORTER_SCENE.instantiate() as Teleporter
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	var receiver: Node2D = Node2D.new()
	player.auto_start = false
	add_child(teleporter)
	add_child(player)
	add_child(receiver)
	await get_tree().process_frame
	teleporter.player = player
	teleporter.teleporting = true
	player.set_teleport_locked(true)
	receiver.global_position = Vector2(500.0, 100.0)
	teleporter._complete_player_teleport(receiver)
	teleporter.animated_sprite.play(&"teleport")
	teleporter._on_animation_finished()
	assert(player.global_position == receiver.global_position)
	assert(not player.teleport_locked)
	assert(not teleporter.teleporting)
	assert(teleporter.player == null)
	teleporter._begin_teleport()
	assert(not teleporter.teleporting)
	teleporter.queue_free()
	player.queue_free()
	receiver.queue_free()
	await get_tree().process_frame
