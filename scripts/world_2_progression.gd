extends Node2D
class_name World2Progression

@onready var lever1: CaveLever = $lever1
@onready var lever2: CaveLever = $lever2
@onready var gate1: CaveGate = $gate1
@onready var gate2: CaveGate = $gate2

const CAMERA_PAN_DURATION: float = 0.4
const GATE_REVEAL_HOLD_DURATION: float = 0.5
const CAMERA_RETURN_DURATION: float = 0.4

var camera_reveal_active: bool = false

func _ready() -> void:
	connect_levers_to_gates(lever1, lever2, gate1, gate2)

func connect_levers_to_gates(first_lever: CaveLever, second_lever: CaveLever, first_gate: CaveGate, second_gate: CaveGate) -> void:
	first_lever.flipped.connect(_reveal_first_gate.bind(first_gate))
	second_lever.flipped.connect(_reveal_second_gate.bind(second_gate))

func _reveal_first_gate(gate: CaveGate) -> void:
	_open_gate_and_reveal(gate)

func _reveal_second_gate(gate: CaveGate) -> void:
	_open_gate_and_reveal(gate)

func _open_gate_and_reveal(gate: CaveGate) -> void:
	var player: Node2D = get_node_or_null("../../knight") as Node2D
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D if player != null else null
	if camera_reveal_active or player == null or camera == null:
		gate.open_gate()
		return
	if not camera.is_current():
		camera.make_current()
	camera_reveal_active = true
	var original_offset: Vector2 = camera.offset
	var target_offset: Vector2 = original_offset + gate.global_position - player.global_position
	var pan_to_gate: Tween = create_tween()
	pan_to_gate.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pan_to_gate.tween_property(camera, "offset", target_offset, CAMERA_PAN_DURATION)
	await pan_to_gate.finished
	if not is_instance_valid(gate) or not is_instance_valid(camera):
		camera_reveal_active = false
		return
	if not gate.opened and not gate.opening:
		gate.open_gate()
	if gate.opening:
		await gate.opened_signal
	await get_tree().create_timer(GATE_REVEAL_HOLD_DURATION).timeout
	if is_instance_valid(camera):
		var return_to_player: Tween = create_tween()
		return_to_player.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return_to_player.tween_property(camera, "offset", original_offset, CAMERA_RETURN_DURATION)
		await return_to_player.finished
	camera_reveal_active = false
