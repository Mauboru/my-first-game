extends CanvasLayer

# Shows what is in GameState (health, stamina, level, objectives) plus what the level tells it to show

@export var message_time := 3.0

@onready var health_bar: ProgressBar = $Status/Health
@onready var stamina_bar: ProgressBar = $Status/Stamina
@onready var level_label: Label = $Status/Level/LevelLabel
@onready var xp_bar: ProgressBar = $Status/Level/XP
@onready var quest_box: Control = $Objetivos
@onready var quest_list: Label = $Objetivos/Lista
@onready var hidden_label: Label = $Escondido
@onready var message_label: Label = $Mensagem
@onready var noise_box: Control = $Barulho
@onready var noise_bar: ProgressBar = $Barulho/Barra
@onready var damage_flash: ColorRect = $Dano
@onready var win_panel: Control = $Vitoria
@onready var lose_panel: Control = $Derrota

var message_left := 0.0

func _ready() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.stamina_changed.connect(_on_stamina_changed)
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.leveled_up.connect(_on_leveled_up)
	GameState.quests_changed.connect(_on_quests_changed)
	_on_health_changed(GameState.health, GameState.max_health)
	_on_stamina_changed(GameState.stamina, GameState.max_stamina)
	_on_xp_changed(GameState.xp, GameState.XP_PER_LEVEL, GameState.level)
	_on_quests_changed()

func _process(delta: float) -> void:
	if message_left > 0.0:
		message_left -= delta
		if message_left <= 0.0:
			message_label.text = ""

# Short notice at the bottom of the screen
func show_message(text: String) -> void:
	message_label.text = text
	message_left = message_time

func set_hidden(value: bool) -> void:
	hidden_label.visible = value

# The noise bar only shows where noise matters
func set_noise(value: float, shown: bool) -> void:
	noise_bar.value = value
	noise_box.visible = shown

func show_win() -> void:
	message_label.text = ""
	win_panel.visible = true

func show_lose() -> void:
	message_label.text = ""
	lose_panel.visible = true

func _on_health_changed(health: float, max_health: float) -> void:
	# The screen flashes red when the player gets hurt
	if health < health_bar.value:
		damage_flash.color.a = 0.45
		create_tween().tween_property(damage_flash, "color:a", 0.0, 0.5)
	health_bar.max_value = max_health
	health_bar.value = health

func _on_stamina_changed(stamina: float, max_stamina: float) -> void:
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina

func _on_xp_changed(xp: int, xp_to_next: int, level: int) -> void:
	xp_bar.max_value = xp_to_next
	xp_bar.value = xp
	level_label.text = "Nv %d" % level

func _on_leveled_up(level: int) -> void:
	show_message("Nível %d!" % level)

# Only the objectives that can be done right now are listed
func _on_quests_changed() -> void:
	var lines: Array[String] = []
	for quest in GameState.get_active_quests():
		lines.append(quest["text"])
	quest_list.text = "\n".join(lines)
	quest_box.visible = not lines.is_empty()
