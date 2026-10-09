extends Node3D

const TASKS := [
	{"id": "treat", "text": "Comer o petisco em cima da geladeira (cozinha)"},
	{"id": "toy", "text": "Pegar a bolinha no alto da estante (sala)"},
	{"id": "key", "text": "Pegar a chave no quarto sem acordar o dono"},
	{"id": "escape", "text": "Abrir o portão do quintal e fugir"},
]

# Floor area of each room (x, z, width, depth), drawn by the map screen
const MAP_ROOMS := {
	"Sala": Rect2(-20, -3, 22, 18),
	"Cozinha": Rect2(2, -15, 18, 30),
	"Quarto": Rect2(-20, -15, 22, 12),
	"Quintal": Rect2(-20, 15, 40, 14),
}
const MAP_PICKUPS := {
	"treat": "Petisco",
	"toy": "Bolinha",
	"key": "Chave",
}

@export var noise_fill_time := 0.8
@export var noise_drain_time := 2.0
@export var message_time := 4.0
@export var moon_speed := 0.03

@onready var player: CharacterBody3D = $Player
@onready var moon: DirectionalLight3D = $Lua
@onready var bedroom_door: Node3D = $Estrutura/PortaQuarto
@onready var gate: Node3D = $Quintal/Portao
@onready var bedroom_exit: Marker3D = $Zonas/SaidaQuarto
@onready var tasks_label: Label = $HUD/Tasks
@onready var message_label: Label = $HUD/Message
@onready var noise_bar: ProgressBar = $HUD/NoiseBar
@onready var win_panel: Control = $HUD/WinPanel
@onready var lose_panel: Control = $HUD/LosePanel
@onready var hidden_label: Label = $HUD/HiddenLabel
@onready var nav_region: NavigationRegion3D = $Navegacao

var done := {}
var noise := 0.0
var in_bedroom := false
var bedroom_open := false
var gate_open := false
var has_won := false
var has_lost := false
var message_left := 0.0

func _ready() -> void:
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.collected.connect(complete_task)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.player_caught.connect(lose)
		player.barked.connect(enemy.hear_noise)
	player.barked.connect(_on_player_barked)
	bake_navigation()
	$Ambiente.stream.loop = true
	$Zonas/QuartoBarulho.body_entered.connect(_on_bedroom_entered)
	$Zonas/QuartoBarulho.body_exited.connect(_on_bedroom_exited)
	$Zonas/Portao.body_entered.connect(_on_gate_reached)
	$Zonas/Fuga.body_entered.connect(_on_escaped)
	update_hud()
	show_message("Você quer fugir! Complete as tarefas para conseguir a chave do portão. Cuidado: tem alguém rondando a casa!")

func _process(delta: float) -> void:
	noise_logic(delta)
	hidden_label.visible = player.is_hidden
	# The sky shader draws the moon where this light points from
	moon.rotate_y(moon_speed * delta)
	if message_left > 0.0:
		message_left -= delta
		if message_left <= 0.0:
			message_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if (has_won or has_lost) and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()

func complete_task(task_id: String) -> void:
	done[task_id] = true
	update_hud()
	
	if task_id == "key":
		show_message("Você pegou a chave! Corra para o portão do quintal.")
	elif not bedroom_open and done.has("treat") and done.has("toy"):
		open_bedroom()
	else:
		show_message("Tarefa concluída!")

func open_bedroom() -> void:
	bedroom_open = true
	update_hud()
	show_message("A porta do quarto abriu! A chave está lá dentro. Aperte C para andar sem fazer barulho.")
	var tween := create_tween()
	tween.tween_property(bedroom_door, "position:y", bedroom_door.position.y - 9.0, 1.5)
	tween.tween_callback(bedroom_door.queue_free)
	# Lets the enemy walk through the doorway once the door is gone
	tween.tween_callback(bake_navigation).set_delay(0.1)

# The owner wakes up when the dog moves around the bedroom without sneaking
func noise_logic(delta: float) -> void:
	if not in_bedroom or has_won:
		return
	var ground_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if not player.is_sneaking and ground_speed > 0.5:
		noise += delta / noise_fill_time
	else:
		noise -= delta / noise_drain_time
	noise = clampf(noise, 0.0, 1.0)
	noise_bar.value = noise
	
	if noise >= 1.0:
		wake_owner()

func wake_owner() -> void:
	noise = 0.0
	player.global_position = bedroom_exit.global_position
	player.velocity = Vector3.ZERO
	show_message("O dono acordou e colocou você para fora! Aperte C para andar sem fazer barulho.")

func _on_player_barked(_noise_position: Vector3) -> void:
	if in_bedroom and not has_won:
		wake_owner()

func _on_bedroom_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	in_bedroom = true
	noise_bar.visible = true

func _on_bedroom_exited(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	in_bedroom = false
	noise = 0.0
	noise_bar.value = 0.0
	noise_bar.visible = false

func _on_gate_reached(body: Node3D) -> void:
	if not body.is_in_group("player") or gate_open: return
	if not done.has("key"):
		show_message("O portão está trancado. Você precisa da chave.")
		return
	gate_open = true
	show_message("O portão abriu! Fuja!")
	create_tween().tween_property(gate, "position:x", gate.position.x + 6.5, 1.2)

func _on_escaped(body: Node3D) -> void:
	if not body.is_in_group("player") or has_won: return
	has_won = true
	done["escape"] = true
	update_hud()
	message_label.text = ""
	player.set_physics_process(false)
	win_panel.visible = true

# The CSG blocks only build their geometry after the first frame, baking before that finds nothing
func bake_navigation() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	nav_region.bake_navigation_mesh()

func lose() -> void:
	if has_won or has_lost: return
	has_lost = true
	message_label.text = ""
	player.set_physics_process(false)
	lose_panel.visible = true

func update_hud() -> void:
	var lines := ["FUGA DO PINSCHER"]
	for task in TASKS:
		var mark := "[x]" if done.has(task["id"]) else "[  ]"
		var text: String = task["text"]
		if task["id"] == "key" and not bedroom_open:
			text += " (porta trancada)"
		lines.append("%s %s" % [mark, text])
	tasks_label.text = "\n".join(lines)

func show_message(text: String) -> void:
	message_label.text = text
	message_left = message_time

# What the dog is carrying, shown by the inventory screen
func get_inventory() -> Array[String]:
	var items: Array[String] = ["Espada"]
	if done.has("toy"):
		items.append("Bolinha")
	if done.has("key") and not gate_open:
		items.append("Chave do portão")
	return items

func get_map_rooms() -> Dictionary:
	return MAP_ROOMS

func get_map_player() -> Node3D:
	return player

# Things still worth going to: items not collected yet, the gate and the hiding spots
func get_map_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for spot in $Esconderijos.get_children():
		markers.append({"position": spot.global_position, "color": Color(0.4, 1.0, 0.5), "radius": 5.0})
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.is_queued_for_deletion(): continue
		markers.append({"position": pickup.global_position, "color": Color(1.0, 0.6, 0.3), "label": MAP_PICKUPS.get(pickup.task_id, "")})
	markers.append({"position": gate.global_position, "color": Color(0.6, 0.8, 1.0), "label": "Portão"})
	return markers
