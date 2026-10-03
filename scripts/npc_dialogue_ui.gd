extends CanvasLayer
class_name NpcDialogueUI

@export var characters_per_second: float = 32.0

@onready var dialogue_box: TextureRect = $Root/DialogueBox
@onready var dialogue_label: Label = $Root/DialogueBox/DialogueLabel
@onready var document_title_box: TextureRect = $Root/DocumentTitleBox
@onready var dialogue_title: Label = $Root/DocumentTitleBox/DialogueTitle
@onready var reward_panel: TextureRect = $Root/RewardPanel
@onready var reward_icon: TextureRect = $Root/RewardPanel/Mp3Charger
@onready var reward_title: Label = $Root/RewardPanel/RewardTitle

const DEFAULT_REWARD_TEXTURE: Texture2D = preload("res://assets/items/mp3charger.png")

var full_text: String = ""
var typing: bool = false
var revealed_characters: float = 0.0


func _ready() -> void:
	dialogue_box.hide()
	document_title_box.hide()
	dialogue_title.hide()
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
	document_title_box.hide()
	dialogue_title.hide()
	dialogue_label.add_theme_font_size_override("font_size", 27)
	dialogue_label.offset_top = 34.0
	dialogue_label.offset_bottom = -34.0
	reward_panel.hide()
	full_text = message
	revealed_characters = 0.0
	typing = not message.is_empty()
	dialogue_label.text = message
	dialogue_label.visible_characters = 0 if typing else -1
	dialogue_box.show()


func show_document_title(title: String) -> void:
	_show_document_text(title, false)


func show_document_description(message: String) -> void:
	_show_document_text(message, true)


func _show_document_text(message: String, use_typewriter: bool) -> void:
	document_title_box.hide()
	dialogue_title.hide()
	dialogue_label.add_theme_font_size_override("font_size", 20)
	dialogue_label.offset_top = 34.0
	dialogue_label.offset_bottom = -34.0
	reward_panel.hide()
	full_text = message
	revealed_characters = 0.0
	typing = use_typewriter and not message.is_empty()
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
	document_title_box.hide()
	dialogue_title.hide()
	dialogue_box.hide()


func show_reward() -> void:
	hide_dialogue()
	reward_icon.texture = DEFAULT_REWARD_TEXTURE
	reward_title.text = "You got a..."
	reward_panel.show()


func show_item_reward(item_texture: Texture2D, item_name: String) -> void:
	hide_dialogue()
	reward_icon.texture = item_texture
	reward_title.text = "You got: %s" % item_name
	reward_panel.show()


func hide_reward() -> void:
	reward_panel.hide()


func hide_all() -> void:
	hide_dialogue()
	hide_reward()
