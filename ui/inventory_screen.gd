extends CanvasLayer

@onready var list: VBoxContainer = $Centro/Caixa/Itens

func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("inventory") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()
	elif not visible and not get_tree().paused and event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		open()

func open() -> void:
	refresh()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func refresh() -> void:
	for child in list.get_children():
		child.queue_free()
	var items: Array = GameState.get_item_names()
	if items.is_empty():
		items = ["(vazio)"]
	for item in items:
		var label := Label.new()
		label.text = item
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 26)
		list.add_child(label)
