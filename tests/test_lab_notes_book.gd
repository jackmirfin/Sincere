extends Node
class_name TestLabNotesBook

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const BOOK_SCENE: PackedScene = preload("res://scenes/labnotesbook.tscn")

func test_book_displays_notes_zoom_and_plays_shrug() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	var book: LabNotesBook = BOOK_SCENE.instantiate() as LabNotesBook
	add_child(book)
	await get_tree().process_frame
	book.call("_on_body_entered", player)
	book.call("_open_notes")
	assert(book.reading)
	assert(player.teleport_locked)
	assert(book.dialogue_ui.dialogue_label.text == LabNotesBook.NOTES_TITLE)
	assert(book.dialogue_ui.dialogue_label.get_parent() == book.dialogue_ui.dialogue_box)
	assert(not book.dialogue_ui.document_title_box.visible and book.dialogue_ui.dialogue_box.visible)
	assert(not book.dialogue_ui.typing, "book title should be immediately readable before advancing")
	assert(book.get_node("BookSprite").scale == Vector2(0.72, 0.72))
	assert(book.dialogue_ui.full_text == LabNotesBook.NOTES_TITLE)
	book._advance_notes()
	assert(book.dialogue_ui.full_text == LabNotesBook.NOTES_TEXT)
	assert(book.dialogue_ui.dialogue_label.get_parent() == book.dialogue_ui.dialogue_box)
	assert(book.dialogue_ui.typing, "description should appear after the title is advanced")
	book._advance_notes()
	assert(not book.dialogue_ui.typing)
	assert(player.animated_sprite.animation == &"shrug")
	await get_tree().create_timer(0.35).timeout
	assert(player.get_node("Camera2D").zoom == LabNotesBook.READ_ZOOM)
	book._advance_notes()
	assert(book.has_read)
	assert(not player.teleport_locked)
	assert(not book.dialogue_ui.dialogue_box.visible)
	player.queue_free()
	book.queue_free()
	await get_tree().process_frame


func test_book_falls_and_comes_to_rest_on_the_floor() -> void:
	var world: Node2D = Node2D.new()
	add_child(world)
	var floor: StaticBody2D = StaticBody2D.new()
	floor.collision_layer = 1
	floor.position = Vector2(0.0, 100.0)
	world.add_child(floor)
	var floor_shape: CollisionShape2D = CollisionShape2D.new()
	var floor_rectangle: RectangleShape2D = RectangleShape2D.new()
	floor_rectangle.size = Vector2(200.0, 8.0)
	floor_shape.shape = floor_rectangle
	floor.add_child(floor_shape)
	var book: LabNotesBook = BOOK_SCENE.instantiate() as LabNotesBook
	world.add_child(book)
	book.position = Vector2.ZERO
	for _frame: int in range(90):
		await get_tree().physics_frame
	assert(book.position.y > 60.0, "book did not fall toward the floor")
	var landed_y: float = book.position.y
	for _frame: int in range(30):
		await get_tree().physics_frame
	assert(absf(book.position.y - landed_y) < 1.0, "book did not settle on the floor")
	world.queue_free()
	await get_tree().process_frame
