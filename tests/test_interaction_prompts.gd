extends Node
class_name TestInteractionPrompts

const TELEPORT_SCENE: PackedScene = preload("res://scenes/teleport.tscn")
const CHARGING_SOCKET_SCENE: PackedScene = preload("res://scenes/chargingsocket.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")


func test_prompt_is_opt_in_for_only_the_guided_teleporter() -> void:
	var first_teleporter: Teleporter = TELEPORT_SCENE.instantiate() as Teleporter
	var second_teleporter: Teleporter = TELEPORT_SCENE.instantiate() as Teleporter
	first_teleporter.show_interact_prompt = true
	assert(first_teleporter.call("should_show_interact_prompt") == true)
	assert(second_teleporter.call("should_show_interact_prompt") == false)
	first_teleporter.free()
	second_teleporter.free()


func test_prompts_hide_permanently_after_first_use() -> void:
	var teleporter: Teleporter = TELEPORT_SCENE.instantiate() as Teleporter
	teleporter.set("show_interact_prompt", true)
	add_child(teleporter)
	var socket: ChargingSocket = CHARGING_SOCKET_SCENE.instantiate() as ChargingSocket
	add_child(socket)
	await get_tree().process_frame
	var teleport_prompt: Label = teleporter.get_node("InteractPrompt") as Label
	var socket_prompt: Label = socket.get_node("InteractPrompt") as Label
	assert(teleport_prompt.visible and socket_prompt.visible)
	teleporter.call("dismiss_interact_prompt")
	socket.call("dismiss_interact_prompt")
	assert(not teleport_prompt.visible and not socket_prompt.visible)
	assert(teleporter.get("prompt_used") == true and socket.get("prompt_used") == true)
	teleporter.queue_free()
	socket.queue_free()
	await get_tree().process_frame


func test_teleport_arrival_effect_overlays_player_from_frame_two() -> void:
	var teleporter: Teleporter = TELEPORT_SCENE.instantiate() as Teleporter
	add_child(teleporter)
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child(player)
	var receiver: Node2D = Node2D.new()
	receiver.global_position = Vector2(180.0, 90.0)
	add_child(receiver)
	await get_tree().process_frame
	teleporter.player = player
	teleporter.call("_complete_player_teleport", receiver)
	var effect: AnimatedSprite2D = teleporter.get("arrival_effect") as AnimatedSprite2D
	assert(effect != null and is_instance_valid(effect))
	assert(player.global_position == receiver.global_position)
	assert(effect.global_position == player.global_position)
	assert(effect.animation == &"teleportappear")
	assert(effect.frame == 2)
	assert(effect.z_index > player.z_index)
	teleporter.queue_free()
	player.queue_free()
	receiver.queue_free()
	await get_tree().process_frame
