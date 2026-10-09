extends CanvasLayer

@onready var menu_box: Control = $Centro/Caixa
@onready var resume_button: Button = $Centro/Caixa/Continuar
@onready var restart_button: Button = $Centro/Caixa/Reiniciar
@onready var options_button: Button = $Centro/Caixa/Opcoes
@onready var quit_button: Button = $Centro/Caixa/Sair

@onready var options_box: Control = $Centro/PainelOpcoes
@onready var volume_label: Label = $Centro/PainelOpcoes/VolumeTexto
@onready var volume_slider: HSlider = $Centro/PainelOpcoes/Volume
@onready var sensitivity_label: Label = $Centro/PainelOpcoes/SensibilidadeTexto
@onready var sensitivity_slider: HSlider = $Centro/PainelOpcoes/Sensibilidade
@onready var fullscreen_check: CheckButton = $Centro/PainelOpcoes/TelaCheia
@onready var back_button: Button = $Centro/PainelOpcoes/Voltar

func _ready() -> void:
	resume_button.pressed.connect(resume)
	restart_button.pressed.connect(restart)
	options_button.pressed.connect(open_options)
	quit_button.pressed.connect(quit)

	# The controls start showing what is saved, and only then start changing it
	volume_slider.value = Settings.volume
	sensitivity_slider.value = Settings.sensitivity
	fullscreen_check.button_pressed = Settings.fullscreen
	update_labels()
	volume_slider.value_changed.connect(on_volume_changed)
	sensitivity_slider.value_changed.connect(on_sensitivity_changed)
	fullscreen_check.toggled.connect(Settings.set_fullscreen)
	back_button.pressed.connect(close_options)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"): return
	get_viewport().set_input_as_handled()
	if options_box.visible:
		close_options()
	elif visible:
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

func open_options() -> void:
	menu_box.visible = false
	options_box.visible = true
	volume_slider.grab_focus()

# Going back is what saves the options to the file
func close_options() -> void:
	Settings.save()
	options_box.visible = false
	menu_box.visible = true
	options_button.grab_focus()

func on_volume_changed(value: float) -> void:
	Settings.set_volume(value)
	update_labels()

func on_sensitivity_changed(value: float) -> void:
	Settings.set_sensitivity(value)
	update_labels()

func update_labels() -> void:
	volume_label.text = "Volume: %d%%" % roundi(Settings.volume * 100.0)
	sensitivity_label.text = "Sensibilidade da câmera: %.1fx" % Settings.sensitivity
