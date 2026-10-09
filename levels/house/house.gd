extends Node3D

# Objectives of this level; "requires" lists the ones that have to be done first
const QUESTS: Array[Dictionary] = [
	{"id": "treat", "text": "Coma o petisco da geladeira", "xp": 25},
	{"id": "toy", "text": "Pegue a bolinha da estante", "xp": 25},
	{"id": "key", "text": "Pegue a chave no quarto", "xp": 50, "requires": ["treat", "toy"]},
	{"id": "escape", "text": "Fuja pelo portão", "xp": 100, "requires": ["key"]},
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
@export var moon_speed := 0.03
@export var enemy_damage := 34.0

@onready var player: CharacterBody3D = $Player
@onready var moon: DirectionalLight3D = $Lua
@onready var bedroom_door: Node3D = $Estrutura/PortaQuarto
@onready var gate: Node3D = $Quintal/Portao
@onready var bedroom_exit: Marker3D = $Zonas/SaidaQuarto
@onready var hud: CanvasLayer = $HUD
@onready var nav_region: NavigationRegion3D = $Navegacao

var noise := 0.0
var in_bedroom := false
var bedroom_open := false
var gate_open := false
var has_won := false
var has_lost := false

func _ready() -> void:
	GameState.reset()
	GameState.set_quests(QUESTS)
	GameState.add_item("sword")
	GameState.died.connect(lose)
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.collected.connect(complete_task)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.player_caught.connect(_on_player_hit.bind(enemy))
		player.barked.connect(enemy.hear_noise)
	player.barked.connect(_on_player_barked)
	bake_navigation()
	$Ambiente.stream.loop = true
	$Zonas/QuartoBarulho.body_entered.connect(_on_bedroom_entered)
	$Zonas/QuartoBarulho.body_exited.connect(_on_bedroom_exited)
	$Zonas/Portao.body_entered.connect(_on_gate_reached)
	$Zonas/Fuga.body_entered.connect(_on_escaped)
	hud.show_message("Fuja de casa. Cuidado com o vizinho!")

func _process(delta: float) -> void:
	noise_logic(delta)
	hud.set_hidden(player.is_hidden)
	# The sky shader draws the moon where this light points from
	moon.rotate_y(moon_speed * delta)

func _unhandled_input(event: InputEvent) -> void:
	if (has_won or has_lost) and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()

func complete_task(task_id: String) -> void:
	GameState.complete_quest(task_id)

	if task_id == "toy":
		GameState.add_item("ball")
	if task_id == "key":
		GameState.add_item("gate_key")
		hud.show_message("Você pegou a chave do portão!")
	elif not bedroom_open and GameState.is_quest_done("treat") and GameState.is_quest_done("toy"):
		open_bedroom()
	else:
		hud.show_message("Objetivo concluído!")

func open_bedroom() -> void:
	bedroom_open = true
	hud.show_message("A porta do quarto abriu. Use C para andar em silêncio.")
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
	hud.set_noise(noise, true)

	if noise >= 1.0:
		wake_owner()

func wake_owner() -> void:
	noise = 0.0
	player.global_position = bedroom_exit.global_position
	player.velocity = Vector3.ZERO
	hud.show_message("O dono acordou! Use C para andar em silêncio.")

func _on_player_barked(_noise_position: Vector3) -> void:
	if in_bedroom and not has_won:
		wake_owner()

func _on_bedroom_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	in_bedroom = true
	hud.set_noise(noise, true)

func _on_bedroom_exited(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	in_bedroom = false
	noise = 0.0
	hud.set_noise(0.0, false)

func _on_gate_reached(body: Node3D) -> void:
	if not body.is_in_group("player") or gate_open: return
	if not GameState.has_item("gate_key"):
		hud.show_message("Trancado. Falta a chave.")
		return
	gate_open = true
	GameState.remove_item("gate_key")
	hud.show_message("Portão aberto!")
	create_tween().tween_property(gate, "position:x", gate.position.x + 6.5, 1.2)

func _on_escaped(body: Node3D) -> void:
	if not body.is_in_group("player") or has_won: return
	has_won = true
	GameState.complete_quest("escape")
	player.set_physics_process(false)
	hud.show_win()

# The CSG blocks only build their geometry after the first frame, baking before that finds nothing
func bake_navigation() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	nav_region.bake_navigation_mesh()

# A punch takes health away, unless the dog is in the middle of an evade; defending softens it
func _on_player_hit(enemy: Node3D) -> void:
	if has_won or has_lost: return
	if player.action == "evade":
		hud.show_message("Esquivou!")
		return
	if player.is_blocking(enemy.global_position):
		hud.show_message("Defendeu!")
		GameState.damage(enemy_damage * player.defend_damage_scale)
		return
	GameState.damage(enemy_damage)

# Called when the health runs out
func lose() -> void:
	if has_won or has_lost: return
	has_lost = true
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.stop()
	hud.show_lose()

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
