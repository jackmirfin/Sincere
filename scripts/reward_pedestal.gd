extends AnimatedSprite2D
class_name RewardPedestal

const DIALOGUE_UI_SCENE: PackedScene = preload("res://scenes/npcdialogueui.tscn")
const INTERACT_PROMPT_SCENE: PackedScene = preload("res://scenes/interactprompt.tscn")
const CLAIMED_REWARDS_META: StringName = &"twilight_reward_items_claimed"
const ITEM_RISE_DISTANCE: float = 34.0
const ITEM_RISE_DURATION: float = 0.45
const ITEM_ICON_SCALE: float = 0.7
const SLOT_ANIMATIONS: Array[StringName] = [&"left", &"middle", &"right"]
const REWARD_POOL: Array[Dictionary] = [
	{"id": &"dualdaggers", "display_name": "Dual Daggers", "texture": preload("res://assets/items/dualdaggers.png")},
	{"id": &"firecharm", "display_name": "Fire Charm", "texture": preload("res://assets/items/firecharm.png")},
	{"id": &"shield", "display_name": "Shield", "texture": preload("res://assets/items/shield.png")}
]

@onready var reward_slots: Array[Area2D] = [$reward1, $reward2, $reward3]

var slot_items: Array[StringName] = [&"", &"", &""]
var slot_icons: Array[Sprite2D] = []
var slot_overlaps: Array[bool] = [false, false, false]
var nearby_player: PlayerController = null
var interact_prompt: Label = null
var dialogue_ui: NpcDialogueUI
var selected_slot_index: int = -1
var selected_item_id: StringName = &""
var selected_player: PlayerController = null
var reward_ui_open: bool = false

func _ready() -> void:
	dialogue_ui = DIALOGUE_UI_SCENE.instantiate() as NpcDialogueUI
	add_child(dialogue_ui)
	interact_prompt = INTERACT_PROMPT_SCENE.instantiate() as Label
	interact_prompt.position = Vector2(-12.0, -52.0)
	interact_prompt.hide()
	add_child(interact_prompt)
	var available_items: Array[Dictionary] = _get_available_items()
	available_items.shuffle()
	for slot_index: int in range(reward_slots.size()):
		var slot: Area2D = reward_slots[slot_index]
		slot.collision_layer = 0
		slot.collision_mask = 2
		slot.monitoring = true
		slot.body_entered.connect(_on_slot_body_entered.bind(slot_index))
		slot.body_exited.connect(_on_slot_body_exited.bind(slot_index))
		var icon: Sprite2D = Sprite2D.new()
		icon.name = "RewardItemIcon"
		icon.position = Vector2(0.0, -12.0)
		icon.scale = Vector2.ONE * ITEM_ICON_SCALE
		if slot_index < available_items.size():
			var item: Dictionary = available_items[slot_index]
			slot_items[slot_index] = item["id"] as StringName
			icon.texture = item["texture"] as Texture2D
		else:
			icon.hide()
			(slot.get_node("CollisionShape2D") as CollisionShape2D).disabled = true
		slot_icons.append(icon)
		slot.add_child(icon)
	if available_items.is_empty():
		play(&"active")

func _get_available_items() -> Array[Dictionary]:
	var claimed_ids: Array[StringName] = _get_claimed_item_ids()
	var available_items: Array[Dictionary] = []
	for item: Dictionary in REWARD_POOL:
		var item_id: StringName = item["id"] as StringName
		if not claimed_ids.has(item_id):
			available_items.append(item)
	return available_items

func _get_claimed_item_ids() -> Array[StringName]:
	var claimed_ids: Array[StringName] = []
	var root: Window = get_tree().root
	if not root.has_meta(CLAIMED_REWARDS_META):
		return claimed_ids
	var stored_ids: Variant = root.get_meta(CLAIMED_REWARDS_META)
	if stored_ids is Array:
		for stored_id: Variant in stored_ids:
			claimed_ids.append(StringName(str(stored_id)))
	return claimed_ids

func _physics_process(_delta: float) -> void:
	_handle_reward_interaction(Input.is_action_just_pressed("interact"))

func _handle_reward_interaction(interact_pressed: bool) -> void:
	if selected_slot_index >= 0:
		return
	var nearby_slot_index: int = _get_nearest_overlapping_slot()
	if nearby_slot_index < 0 or nearby_player == null:
		interact_prompt.hide()
		return
	_update_interact_prompt(nearby_slot_index)
	if interact_pressed:
		_select_reward(nearby_slot_index, nearby_player)

func _get_nearest_overlapping_slot() -> int:
	if nearby_player == null:
		return -1
	var nearest_slot_index: int = -1
	var nearest_distance_squared: float = INF
	for slot_index: int in range(reward_slots.size()):
		if not slot_overlaps[slot_index] or slot_items[slot_index] == &"":
			continue
		var distance_squared: float = nearby_player.global_position.distance_squared_to(reward_slots[slot_index].global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_slot_index = slot_index
	return nearest_slot_index

func _update_interact_prompt(slot_index: int) -> void:
	if not is_instance_valid(interact_prompt) or slot_index < 0 or slot_index >= reward_slots.size():
		if is_instance_valid(interact_prompt):
			interact_prompt.hide()
		return
	interact_prompt.global_position = reward_slots[slot_index].global_position + Vector2(-12.0, -52.0)
	interact_prompt.show()

func _on_slot_body_entered(body: Node2D, slot_index: int) -> void:
	if not body.is_in_group("player") or selected_slot_index >= 0:
		return
	var entered_player: PlayerController = body as PlayerController
	if entered_player == null:
		return
	nearby_player = entered_player
	slot_overlaps[slot_index] = true
	_update_interact_prompt(_get_nearest_overlapping_slot())

func _on_slot_body_exited(body: Node2D, slot_index: int) -> void:
	if body != nearby_player or slot_index < 0 or slot_index >= slot_overlaps.size():
		return
	slot_overlaps[slot_index] = false
	if not slot_overlaps.has(true):
		nearby_player = null
	_update_interact_prompt(_get_nearest_overlapping_slot())

func _select_reward(slot_index: int, player: PlayerController) -> void:
	if player == null or selected_slot_index >= 0 or slot_index < 0 or slot_index >= slot_items.size():
		return
	var item_id: StringName = slot_items[slot_index]
	if item_id == &"":
		return
	selected_slot_index = slot_index
	selected_item_id = item_id
	selected_player = player
	interact_prompt.hide()
	selected_player.set_teleport_locked(true)
	var claimed_ids: Array[StringName] = _get_claimed_item_ids()
	claimed_ids.append(selected_item_id)
	get_tree().root.set_meta(CLAIMED_REWARDS_META, claimed_ids)
	for index: int in range(reward_slots.size()):
		reward_slots[index].set_deferred("monitoring", false)
		(reward_slots[index].get_node("CollisionShape2D") as CollisionShape2D).set_deferred("disabled", true)
		if index != slot_index:
			slot_icons[index].hide()
	play(SLOT_ANIMATIONS[slot_index])
	var raised_position: Vector2 = slot_icons[slot_index].position + Vector2(0.0, -ITEM_RISE_DISTANCE)
	var rise_tween: Tween = create_tween()
	rise_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise_tween.tween_property(slot_icons[slot_index], "position", raised_position, ITEM_RISE_DURATION)
	rise_tween.finished.connect(_show_reward_ui, CONNECT_ONE_SHOT)

func _show_reward_ui() -> void:
	var item: Dictionary = _get_reward_definition(selected_item_id)
	if item.is_empty():
		return
	dialogue_ui.show_item_reward(item["texture"] as Texture2D, str(item["display_name"]))
	reward_ui_open = true

func _get_reward_definition(item_id: StringName) -> Dictionary:
	for item: Dictionary in REWARD_POOL:
		if item["id"] == item_id:
			return item
	return {}

func _unhandled_input(event: InputEvent) -> void:
	if not reward_ui_open or not event.is_action_pressed("interact") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	dialogue_ui.hide_reward()
	reward_ui_open = false
	if is_instance_valid(selected_player):
		selected_player.set_teleport_locked(false)
