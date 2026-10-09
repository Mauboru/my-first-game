extends Node

# Everything about the player that has to outlive a scene: health, stamina, XP, items and quests.
# Scenes read and change it through the functions below, and the HUD listens to the signals.

signal health_changed(health: float, max_health: float)
signal stamina_changed(stamina: float, max_stamina: float)
signal xp_changed(xp: int, xp_to_next: int, level: int)
signal leveled_up(level: int)
signal inventory_changed
signal quests_changed
signal died

const XP_PER_LEVEL := 100
# Item ids and the names shown on screen
const ITEMS := {
	"sword": "Espada",
	"ball": "Bolinha",
	"gate_key": "Chave do portão",
}

@export var max_health := 100.0
@export var max_stamina := 100.0
@export var stamina_regen := 25.0
# Seconds without spending stamina before it starts coming back
@export var stamina_regen_delay := 0.8

var health := 100.0
var stamina := 100.0
var xp := 0
var level := 1
var inventory: Array[String] = []
# Each quest is {"id", "text", "xp", "requires": [ids that must be done first], "done"}
var quests: Array[Dictionary] = []
var regen_wait := 0.0

func _process(delta: float) -> void:
	regen_wait -= delta
	if regen_wait <= 0.0 and stamina < max_stamina and health > 0.0:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)
		stamina_changed.emit(stamina, max_stamina)

# Starts a new game from scratch
func reset() -> void:
	health = max_health
	stamina = max_stamina
	xp = 0
	level = 1
	inventory.clear()
	quests.clear()
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	xp_changed.emit(xp, XP_PER_LEVEL, level)
	inventory_changed.emit()
	quests_changed.emit()

func damage(amount: float) -> void:
	if health <= 0.0: return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health == 0.0:
		died.emit()

func heal(amount: float) -> void:
	if health <= 0.0: return
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)

# Spends stamina for one action; returns false, and spends nothing, when there is not enough
func use_stamina(amount: float) -> bool:
	if stamina < amount: return false
	drain_stamina(amount)
	return true

# Spends stamina little by little, for things that last, like running
func drain_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	regen_wait = stamina_regen_delay
	stamina_changed.emit(stamina, max_stamina)

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= XP_PER_LEVEL:
		xp -= XP_PER_LEVEL
		level += 1
		leveled_up.emit(level)
	xp_changed.emit(xp, XP_PER_LEVEL, level)

func add_item(item_id: String) -> void:
	if has_item(item_id): return
	inventory.append(item_id)
	inventory_changed.emit()

func remove_item(item_id: String) -> void:
	inventory.erase(item_id)
	inventory_changed.emit()

func has_item(item_id: String) -> bool:
	return item_id in inventory

func get_item_names() -> Array[String]:
	var names: Array[String] = []
	for item_id in inventory:
		names.append(ITEMS.get(item_id, item_id))
	return names

func set_quests(new_quests: Array[Dictionary]) -> void:
	quests.clear()
	for quest in new_quests:
		var copy := quest.duplicate()
		copy["done"] = false
		quests.append(copy)
	quests_changed.emit()

# Marks the quest as done and gives its XP
func complete_quest(quest_id: String) -> void:
	for quest in quests:
		if quest["id"] == quest_id and not quest["done"]:
			quest["done"] = true
			add_xp(quest.get("xp", 0))
			quests_changed.emit()

func is_quest_done(quest_id: String) -> bool:
	for quest in quests:
		if quest["id"] == quest_id:
			return quest["done"]
	return false

# Quests the player can work on now: not done, and with everything they depend on done
func get_active_quests() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for quest in quests:
		if quest["done"]: continue
		var unlocked := true
		for required in quest.get("requires", []):
			if not is_quest_done(required):
				unlocked = false
		if unlocked:
			active.append(quest)
	return active
