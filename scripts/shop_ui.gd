extends CanvasLayer
class_name ShopUI

signal shop_closed

const PIXEL_FONT: Font = preload("res://assets/fonts/pixelfont.ttf")
const COIN_SOUND: AudioStream = preload("res://assets/sounds/coinpickup.mp3")
const SHOP_ART: Texture2D = preload("res://assets/ui/shopui.png")

# The shop frame is drawn inside shopui.png. Crop to it and lay every control out
# in artwork pixels so each one lands on the box the art draws for it.
const ART_REGION := Rect2(56.0, 89.0, 152.0, 87.0)
const FRAME_SIZE := Vector2(152.0, 87.0)
const TITLE_BOX := Rect2(24.0, 3.0, 104.0, 11.0)
const CLOSE_BOX := Rect2(127.0, 4.0, 15.0, 10.0)
const DESC_BOX := Rect2(10.0, 63.0, 96.0, 16.0)
const BUY_BOX := Rect2(108.0, 66.0, 34.0, 11.0)
const ITEM_BOXES: Array = [
	Rect2(10.0, 18.0, 42.0, 31.0),
	Rect2(56.0, 18.0, 40.0, 31.0),
	Rect2(100.0, 18.0, 42.0, 31.0),
]
const PRICE_BOXES: Array = [
	Rect2(12.0, 51.0, 38.0, 8.0),
	Rect2(57.0, 51.0, 38.0, 8.0),
	Rect2(102.0, 51.0, 38.0, 8.0),
]
const VIEWPORT_FRACTION := 0.72
const TITLE_FONT := 7
const ITEM_FONT := 6
const DESC_FONT := 5
const BUY_FONT := 7
const COIN_FONT := 7

const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const BG_BORDER := Color(0.85, 0.72, 0.42, 1.0)
const BOX_BORDER := Color(0.45, 0.38, 0.30, 1.0)
const SELECTED_BORDER := Color(1.0, 0.86, 0.46, 1.0)
const TEXT_COLOR := Color(1.0, 0.94, 0.72, 1.0)
const MUTED_COLOR := Color(0.7, 0.62, 0.5, 1.0)
const DISABLED_COLOR := Color(0.42, 0.38, 0.34, 1.0)

var items: Array[Dictionary] = []
var selected_index: int = 0
var sold: Dictionary = {}
var shop_open: bool = false
var player: PlayerController = null

var backdrop: ColorRect
var window: Panel
var frame: TextureRect
var header_label: Label
var close_button: Button
var item_buttons: Array[Button] = []
var item_icons: Array[TextureRect] = []
var price_labels: Array[Label] = []
var name_label: Label
var desc_label: Label
var desc_panel: Panel
var buy_button: Button
var coin_sprite: AnimatedSprite2D
var coin_label: Label
var coin_audio: AudioStreamPlayer

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	if items.is_empty():
		items = default_items()
	_build()
	visible = false
	get_viewport().size_changed.connect(_layout)
	call_deferred("_layout")

func default_items() -> Array[Dictionary]:
	return [
		{"id": &"whetstone", "name": "Whetstone", "price": 330, "desc": "Increase melee damage.", "icon": "res://assets/items/whetstone.png"},
		{"id": &"portablecharger", "name": "Portable Charger", "price": 375, "desc": "Increase max health", "icon": "res://assets/items/portablecharger.png"},
		{"id": &"coffee", "name": "Coffee", "price": 135, "desc": "Increase movement speed", "icon": "res://assets/items/coffee.png"},
	]

func remaining_midworld_items() -> Array[Dictionary]:
	var main_loop: MainLoop = Engine.get_main_loop()
	var tree: SceneTree = main_loop as SceneTree
	var currency: Node = tree.root.get_node_or_null("CurrencyManager") if tree != null else null
	var remaining_items: Array[Dictionary] = []
	var catalog: Array[Dictionary] = default_items()
	for item_id: StringName in [&"portablecharger", &"whetstone"]:
		for item: Dictionary in catalog:
			if StringName(item["id"]) != item_id:
				continue
			if currency == null or not bool(currency.call("has_purchased_shop_item", item_id)):
				remaining_items.append(item.duplicate(true))
	if currency == null or not bool(currency.call("has_purchased_shop_item", &"resin")):
		remaining_items.append({
			"id": &"resin",
			"name": "Resin",
			"price": 200,
			"desc": "Makes torches last longer.",
			"icon": "res://assets/items/resin.png"
		})
	return remaining_items

func _build() -> void:
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	window = Panel.new()
	window.name = "Window"
	window.add_theme_stylebox_override("panel", _empty_box())
	add_child(window)

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = SHOP_ART
	atlas.region = ART_REGION
	frame = TextureRect.new()
	frame.name = "Frame"
	frame.texture = atlas
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(frame)

	header_label = _make_label("SHOP", TEXT_COLOR, 28)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window.add_child(header_label)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_override("font", PIXEL_FONT)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
	close_button.add_theme_color_override("font_hover_color", SELECTED_BORDER)
	close_button.add_theme_stylebox_override("normal", _empty_box())
	close_button.add_theme_stylebox_override("hover", _style_box(Color(1.0, 0.86, 0.46, 0.12), Color(1.0, 0.86, 0.46, 0.45), 2, 2))
	close_button.add_theme_stylebox_override("pressed", _style_box(Color(1.0, 0.86, 0.46, 0.22), Color(1.0, 0.86, 0.46, 0.7), 2, 2))
	close_button.pressed.connect(close)
	window.add_child(close_button)

	for index: int in range(items.size()):
		var button: Button = Button.new()
		button.name = "Item%d" % index
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", _empty_box())
		button.add_theme_stylebox_override("hover", _style_box(Color(1.0, 0.86, 0.46, 0.12), Color(1.0, 0.86, 0.46, 0.55), 2, 2))
		button.add_theme_stylebox_override("pressed", _style_box(Color(1.0, 0.86, 0.46, 0.22), SELECTED_BORDER, 2, 2))
		button.pressed.connect(_on_item_pressed.bind(index))
		window.add_child(button)
		item_buttons.append(button)

		var icon: TextureRect = TextureRect.new()
		icon.name = "Icon"
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_path: String = String(items[index]["icon"])
		if ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path) as Texture2D
		button.add_child(icon)
		item_icons.append(icon)

		var price: Label = _make_label(str(int(items[index]["price"])), TEXT_COLOR, 22)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.name = "Price"
		button.add_child(price)
		price_labels.append(price)
		button.set_meta("index", index)

	desc_panel = Panel.new()
	desc_panel.name = "DescPanel"
	desc_panel.add_theme_stylebox_override("panel", _empty_box())
	window.add_child(desc_panel)

	name_label = _make_label("", TEXT_COLOR, 24)
	desc_panel.add_child(name_label)
	desc_label = _make_label("", MUTED_COLOR, 20)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_panel.add_child(desc_label)

	buy_button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = "buy"
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy_button.add_theme_font_override("font", PIXEL_FONT)
	buy_button.add_theme_font_size_override("font_size", 26)
	buy_button.add_theme_color_override("font_color", TEXT_COLOR)
	buy_button.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.08, 1.0))
	buy_button.add_theme_color_override("font_disabled_color", DISABLED_COLOR)
	buy_button.add_theme_stylebox_override("normal", _empty_box())
	buy_button.add_theme_stylebox_override("hover", _style_box(SELECTED_BORDER, BG_BORDER, 2, 3))
	buy_button.add_theme_stylebox_override("pressed", _style_box(Color(1.0, 0.72, 0.3, 1.0), BG_BORDER, 2, 3))
	buy_button.add_theme_stylebox_override("disabled", _style_box(Color(0.05, 0.03, 0.06, 0.6), BOX_BORDER, 2, 3))
	buy_button.pressed.connect(buy)
	window.add_child(buy_button)

	coin_sprite = AnimatedSprite2D.new()
	coin_sprite.name = "CoinSprite"
	coin_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_sprite.scale = Vector2(2.5, 2.5)
	var registry: Node = get_node_or_null("/root/CoinRegistry")
	if registry != null:
		var data: CoinTypeData = registry.call("get_type", &"gold") as CoinTypeData
		if data != null and data.frames != null:
			coin_sprite.sprite_frames = data.frames
			coin_sprite.play(&"coin")
	window.add_child(coin_sprite)

	coin_label = _make_label("0", TEXT_COLOR, 26)
	window.add_child(coin_label)

	coin_audio = AudioStreamPlayer.new()
	coin_audio.stream = COIN_SOUND
	coin_audio.volume_db = 2.0
	add_child(coin_audio)

	var currency: Node = get_node_or_null("/root/CurrencyManager")
	if currency != null and currency.has_signal("currency_changed") and not currency.currency_changed.is_connected(_on_currency_changed):
		currency.currency_changed.connect(_on_currency_changed)

func _make_label(label_text: String, colour: Color, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style_box(fill: Color, border: Color, border_width: int = 2, radius: int = 3) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

func _place(control: Control, box: Rect2, ui_scale: float) -> void:
	control.position = box.position * ui_scale
	control.size = box.size * ui_scale

func _layout() -> void:
	if backdrop == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size

	# Scale the shopui.png frame to the viewport, then place each control on the
	# box the artwork draws for it.
	var ui_scale: float = viewport_size.x * VIEWPORT_FRACTION / FRAME_SIZE.x
	var frame_px: Vector2 = FRAME_SIZE * ui_scale
	window.position = (viewport_size - frame_px) * 0.5
	window.size = frame_px
	if frame != null:
		frame.position = Vector2.ZERO
		frame.size = frame_px

	header_label.add_theme_font_size_override("font_size", int(round(TITLE_FONT * ui_scale)))
	_place(header_label, Rect2(TITLE_BOX.position + Vector2(5.0, 0.0), Vector2(TITLE_BOX.size.x - 48.0, TITLE_BOX.size.y)), ui_scale)

	coin_sprite.position = (TITLE_BOX.position + Vector2(TITLE_BOX.size.x - 46.0, TITLE_BOX.size.y * 0.5)) * ui_scale
	coin_sprite.scale = Vector2.ONE * (0.5 * ui_scale)
	coin_label.add_theme_font_size_override("font_size", int(round(COIN_FONT * ui_scale)))
	_place(coin_label, Rect2(TITLE_BOX.position + Vector2(TITLE_BOX.size.x - 38.0, 0.0), Vector2(34.0, TITLE_BOX.size.y)), ui_scale)

	close_button.add_theme_font_size_override("font_size", int(round(TITLE_FONT * ui_scale)))
	_place(close_button, CLOSE_BOX, ui_scale)

	for index: int in range(item_buttons.size()):
		var item_box: Rect2 = ITEM_BOXES[index]
		_place(item_buttons[index], item_box, ui_scale)
		var inset: Vector2 = Vector2(4.0, 3.0)
		# The icon is a child of the button, so its rect is button-local.
		_place(item_icons[index], Rect2(inset, item_box.size - inset * 2.0), ui_scale)
		price_labels[index].add_theme_font_size_override("font_size", int(round(ITEM_FONT * ui_scale)))
		# The price label is a child of the button, so convert the artwork rect
		# into button-local space.
		_place(price_labels[index], Rect2(PRICE_BOXES[index].position - item_box.position, PRICE_BOXES[index].size), ui_scale)

	_place(desc_panel, DESC_BOX, ui_scale)
	name_label.add_theme_font_size_override("font_size", int(round(ITEM_FONT * ui_scale)))
	_place(name_label, Rect2(4.0, 1.0, DESC_BOX.size.x - 8.0, 7.0), ui_scale)
	desc_label.add_theme_font_size_override("font_size", int(round(DESC_FONT * ui_scale)))
	_place(desc_label, Rect2(4.0, 8.0, DESC_BOX.size.x - 8.0, DESC_BOX.size.y - 9.0), ui_scale)

	buy_button.add_theme_font_size_override("font_size", int(round(BUY_FONT * ui_scale)))
	_place(buy_button, BUY_BOX, ui_scale)

func open(p_player: PlayerController) -> void:
	player = p_player
	if player != null:
		player.set_teleport_locked(true)
	shop_open = true
	visible = true
	_layout()
	_refresh()

func close() -> void:
	if not shop_open:
		return
	shop_open = false
	visible = false
	if player != null and is_instance_valid(player):
		player.set_teleport_locked(false)
	shop_closed.emit()

func is_item_sold(index: int) -> bool:
	return bool(sold.get(index, false))

func selected_item() -> Dictionary:
	if selected_index < 0 or selected_index >= items.size():
		return {}
	return items[selected_index]

func _on_item_pressed(index: int) -> void:
	selected_index = index
	_refresh()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()

func _unhandled_input(event: InputEvent) -> void:
	if not shop_open:
		return
	var escape_pressed: bool = event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE and (event as InputEventKey).pressed
	if escape_pressed or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _on_currency_changed(_total: int, _delta: int) -> void:
	_refresh()

func _refresh() -> void:
	var total: int = 0
	var currency: Node = get_node_or_null("/root/CurrencyManager")
	if currency != null:
		total = int(currency.get("total_currency"))
	if coin_label != null:
		coin_label.text = str(total)
	var item: Dictionary = selected_item()
	if not item.is_empty():
		name_label.text = String(item["name"])
		desc_label.text = String(item["desc"])
	for index: int in range(item_buttons.size()):
		var is_sold: bool = is_item_sold(index)
		var is_selected: bool = index == selected_index
		if is_selected:
			item_buttons[index].add_theme_stylebox_override("normal", _style_box(Color(1.0, 0.9, 0.5, 0.14), Color(1.0, 0.92, 0.55, 0.95), 2, 3))
		else:
			item_buttons[index].add_theme_stylebox_override("normal", _empty_box())
		item_icons[index].visible = not is_sold
		var price: float = float(int(items[index]["price"]))
		price_labels[index].text = "SOLD" if is_sold else str(int(price))
		price_labels[index].add_theme_color_override("font_color", MUTED_COLOR if is_sold else TEXT_COLOR)
	var can_buy: bool = not item.is_empty() and not is_item_sold(selected_index) and total >= int(item.get("price", 0))
	buy_button.disabled = not can_buy

func buy() -> bool:
	if not shop_open:
		return false
	var item: Dictionary = selected_item()
	if item.is_empty() or is_item_sold(selected_index):
		return false
	var price: int = int(item.get("price", 0))
	var currency: Node = get_node_or_null("/root/CurrencyManager")
	if currency == null or not bool(currency.call("spend_currency", price)):
		return false
	if coin_audio != null:
		coin_audio.play()
	sold[selected_index] = true
	_apply_effect(item)
	if currency.has_method("record_shop_purchase"):
		currency.call("record_shop_purchase", StringName(item["id"]))
	_refresh()
	return true

func _apply_effect(item: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	match StringName(item["id"]):
		&"whetstone":
			player.add_attack_damage(5)
		&"portablecharger":
			player.add_max_health_percent(0.10)
		&"coffee":
			player.add_move_speed_percent(0.10)
		&"resin":
			var currency: Node = get_node_or_null("/root/CurrencyManager")
			if currency != null and currency.has_method("extend_torch_duration"):
				currency.call("extend_torch_duration", 1.5)