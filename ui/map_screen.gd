extends CanvasLayer

@onready var view: Control = $Mapa

func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("map") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()
	elif not visible and not get_tree().paused and event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		open()

func _process(_delta: float) -> void:
	if visible:
		view.queue_redraw()

func open() -> void:
	view.level = get_parent()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false
