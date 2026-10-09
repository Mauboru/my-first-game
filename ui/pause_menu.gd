extends CanvasLayer

@onready var resume_button: Button = $Centro/Caixa/Continuar
@onready var restart_button: Button = $Centro/Caixa/Reiniciar
@onready var quit_button: Button = $Centro/Caixa/Sair

func _ready() -> void:
	resume_button.pressed.connect(resume)
	restart_button.pressed.connect(restart)
	quit_button.pressed.connect(quit)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"): return
	get_viewport().set_input_as_handled()
	if visible:
		resume()
	else:
		pause()

func pause() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()

func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func quit() -> void:
	get_tree().quit()
