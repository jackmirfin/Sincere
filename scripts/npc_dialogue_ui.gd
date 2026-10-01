extends CanvasLayer
class_name NpcDialogueUI

@export var characters_per_second: float = 32.0

@onready var dialogue_box: TextureRect = $Root/DialogueBox
@onready var dialogue_label: Label = $Root/DialogueBox/DialogueLabel
@onready var reward_panel: TextureRect = $Root/RewardPanel

var full_text: String = ""
var typing: bool = false
var revealed_characters: float = 0.0


func _ready() -> void:
	dialogue_box.hide()
	reward_panel.hide()


func _process(delta: float) -> void:
	if not typing:
		return
	revealed_characters += characters_per_second * delta
	dialogue_label.visible_characters = mini(full_text.length(), int(revealed_characters))
	if dialogue_label.visible_characters >= full_text.length():
		typing = false
		dialogue_label.visible_characters = -1


func show_dialogue(message: String) -> void:
	reward_panel.hide()
	full_text = message
	revealed_characters = 0.0
	typing = not message.is_empty()
	dialogue_label.text = message
	dialogue_label.visible_characters = 0 if typing else -1
	dialogue_box.show()


func complete_typewriter() -> void:
	if not typing:
		return
	typing = false
	revealed_characters = float(full_text.length())
	dialogue_label.visible_characters = -1


func hide_dialogue() -> void:
	typing = false
	dialogue_box.hide()


func show_reward() -> void:
	hide_dialogue()
	reward_panel.show()


func hide_reward() -> void:
	reward_panel.hide()


func hide_all() -> void:
	hide_dialogue()
	hide_reward()
