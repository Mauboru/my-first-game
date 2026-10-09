extends AudioStreamPlayer3D

const GRASS_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/footsteps/grass1.mp3"),
	preload("res://assets/audio/footsteps/grass2.mp3"),
]
const STONE_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/footsteps/stone1.mp3"),
	preload("res://assets/audio/footsteps/stone2.mp3"),
]

@export var stride := 1.2
@export var pitch_variation := 0.1

@onready var body: CharacterBody3D = get_parent()

var distance_walked := 0.0

# Called by the body every physics frame; plays one step for each stride it walks
func step_logic(delta: float) -> void:
	if not body.is_on_floor(): return
	distance_walked += Vector2(body.velocity.x, body.velocity.z).length() * delta
	if distance_walked < stride: return
	distance_walked = 0.0
	var sounds := GRASS_SOUNDS if is_on_grass() else STONE_SOUNDS
	stream = sounds.pick_random()
	pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	play()

# Floors in the "grass" group sound like grass, everything else sounds like the house floor
func is_on_grass() -> bool:
	var from := body.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN)
	query.exclude = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider.is_in_group("grass")
