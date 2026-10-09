extends CharacterBody3D

signal player_caught

enum State { PATROL, WAIT, INVESTIGATE, CHASE, ATTACK }

@export var patrol_route: Node3D
@export var patrol_speed := 3.0
@export var chase_speed := 6.5
@export var acceleration := 20.0
@export var turn_speed := 6.0
@export var wait_time := 2.5
@export var arrive_distance := 1.5

@export var view_distance := 18.0
@export var view_angle := 110.0
@export var sense_distance := 3.5
@export var memory_time := 1.5
@export var give_up_time := 8.0

@export var hear_distance := 45.0
@export var investigate_speed := 4.0

@export var attack_range := 3.2
@export var hit_range := 3.5
@export var attack_anim_speed := 1.6
@export var max_anim_speed := 2.0

@export var voice_min_wait := 8.0
@export var voice_max_wait := 20.0

@onready var footsteps = $Passos
@onready var voice_audio: AudioStreamPlayer3D = $Voz
@onready var model: Node3D = $Model
@onready var anim_player: AnimationPlayer = $Model/AnimationPlayer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")

const ANIMATIONS := {
	"idle": preload("res://entities/enemie/animations/idle.fbx"),
	"walk": preload("res://entities/enemie/animations/walk.fbx"),
	"attack": preload("res://entities/enemie/animations/attack.fbx"),
}
const VOICE_SOUNDS: Array[AudioStream] = [
	preload("res://entities/enemie/audio/enemie1.mp3"),
	preload("res://entities/enemie/audio/enemie2.mp3"),
]
const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"
const LOOPING := ["idle", "walk"]
# walk.fbx is a walking-backwards animation, so it is played in reverse
const REVERSED := ["walk"]
# Moment of the attack animation when the fist reaches the target
const ATTACK_HIT_TIME := 1.05

# Measured on the model before it is scaled
const NATURAL_WALK_SPEED := 1.17
const EYE_HEIGHT := 1.6
const PLAYER_CENTER_HEIGHT := 0.7
const REPATH_INTERVAL := 0.2
const STUCK_TIME := 2.0

var state := State.PATROL
var current_animation := ""
var patrol_index := 0
var destination := Vector3.ZERO
var target_speed := 0.0
var wait_left := 0.0
var repath_left := 0.0
var stuck_time := 0.0
var sees_player := false
var time_since_seen := INF
var last_known_position := Vector3.ZERO
var has_hit := false
var voice_left := 0.0

func _ready() -> void:
	load_animations()
	destination = global_position
	voice_left = randf_range(voice_min_wait, voice_max_wait)

func _physics_process(delta: float) -> void:
	look_for_player(delta)
	match state:
		State.PATROL: patrol_logic(delta)
		State.WAIT: wait_logic(delta)
		State.INVESTIGATE: investigate_logic(delta)
		State.CHASE: chase_logic()
		State.ATTACK: attack_logic()
	move_logic(delta)
	move_and_slide()
	animation_logic()
	footsteps.step_logic(delta)
	voice_logic(delta)

# Makes a sound every now and then, the wait only counts while it is quiet
func voice_logic(delta: float) -> void:
	if voice_audio.playing: return
	voice_left -= delta
	if voice_left > 0.0: return
	voice_left = randf_range(voice_min_wait, voice_max_wait)
	voice_audio.stream = VOICE_SOUNDS.pick_random()
	voice_audio.play()

func look_for_player(delta: float) -> void:
	sees_player = can_see_player()
	time_since_seen = 0.0 if sees_player else time_since_seen + delta
	# Keeps tracking the player for a moment after losing sight of it
	if player != null and time_since_seen < memory_time:
		last_known_position = player.global_position
	if sees_player and state in [State.PATROL, State.WAIT, State.INVESTIGATE]:
		state = State.CHASE

func can_see_player() -> bool:
	if player == null or player.is_hidden: return false
	var eye := global_position + Vector3.UP * EYE_HEIGHT * model.scale.y
	var target := player.global_position + Vector3.UP * PLAYER_CENTER_HEIGHT
	var to_player := flat(target - eye)
	if to_player.length() > view_distance: return false
	# Up close the player is noticed even from behind
	if to_player.length() > sense_distance and facing().angle_to(to_player) > deg_to_rad(view_angle * 0.5):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player

func patrol_logic(delta: float) -> void:
	if patrol_route == null or patrol_route.get_child_count() == 0:
		target_speed = 0.0
		return
	var point: Node3D = patrol_route.get_child(patrol_index)
	destination = point.global_position
	target_speed = patrol_speed
	# Skips the point when there is no way to get there
	stuck_time = stuck_time + delta if nav_agent.is_navigation_finished() else 0.0
	if distance_to(destination) < arrive_distance or stuck_time > STUCK_TIME:
		patrol_index = (patrol_index + 1) % patrol_route.get_child_count()
		start_waiting()

func start_waiting() -> void:
	state = State.WAIT
	wait_left = wait_time
	stuck_time = 0.0

func wait_logic(delta: float) -> void:
	target_speed = 0.0
	wait_left -= delta
	if wait_left <= 0.0:
		state = State.PATROL

# Goes check a noise, then carries on with the patrol from the point closest to it
func hear_noise(noise_position: Vector3) -> void:
	if state in [State.CHASE, State.ATTACK] or not is_physics_processing(): return
	if distance_to(noise_position) > hear_distance: return
	state = State.INVESTIGATE
	destination = noise_position
	patrol_index = closest_patrol_point(noise_position)
	stuck_time = 0.0
	repath_left = 0.0

func investigate_logic(delta: float) -> void:
	target_speed = investigate_speed
	# Gives up when the noise came from somewhere out of reach
	stuck_time = stuck_time + delta if nav_agent.is_navigation_finished() else 0.0
	if distance_to(destination) < arrive_distance or stuck_time > STUCK_TIME:
		start_waiting()

func closest_patrol_point(point: Vector3) -> int:
	var closest := patrol_index
	var closest_distance := INF
	if patrol_route == null: return closest
	for index in patrol_route.get_child_count():
		var patrol_point: Node3D = patrol_route.get_child(index)
		var distance := patrol_point.global_position.distance_to(point)
		if distance < closest_distance:
			closest = index
			closest_distance = distance
	return closest

func chase_logic() -> void:
	destination = last_known_position
	target_speed = chase_speed
	var lost_player := time_since_seen > memory_time
	if lost_player and (distance_to(destination) < arrive_distance or time_since_seen > give_up_time):
		start_waiting()
	elif sees_player and distance_to(player.global_position) < attack_range and can_reach(player):
		start_attack()

func start_attack() -> void:
	state = State.ATTACK
	has_hit = false
	current_animation = "attack"
	anim_player.speed_scale = 1.0
	anim_player.play("attack", 0.15, attack_anim_speed)

func attack_logic() -> void:
	if anim_player.current_animation != "attack":
		state = State.CHASE
		return
	if has_hit:
		target_speed = 0.0
		return
	# Keeps lunging at the player until the fist lands
	destination = player.global_position
	target_speed = chase_speed
	if anim_player.current_animation_position >= ATTACK_HIT_TIME:
		has_hit = true
		if is_player_hit():
			catch_player()

func is_player_hit() -> bool:
	var to_player := flat(player.global_position - global_position)
	return to_player.length() < hit_range and can_reach(player) and facing().angle_to(to_player) < PI / 3.0

func catch_player() -> void:
	player_caught.emit()

# Where the player's focus aims at
func get_focus_point() -> Vector3:
	return global_position + Vector3.UP * EYE_HEIGHT * model.scale.y * 0.75

# Freezes the enemy, for when the game is over
func stop() -> void:
	velocity = Vector3.ZERO
	set_physics_process(false)
	anim_player.queue("idle")

# The player is out of reach when standing on top of tall furniture
func can_reach(body: Node3D) -> bool:
	var height := body.global_position.y - global_position.y
	return height > -1.0 and height < EYE_HEIGHT * model.scale.y * 0.5

func move_logic(delta: float) -> void:
	repath_left -= delta
	if repath_left <= 0.0:
		repath_left = REPATH_INTERVAL
		nav_agent.target_position = destination

	var direction := Vector3.ZERO
	if target_speed > 0.0 and not nav_agent.is_navigation_finished():
		direction = flat(nav_agent.get_next_path_position() - global_position).normalized()

	var vel_2d := Vector2(velocity.x, velocity.z)
	vel_2d = vel_2d.move_toward(Vector2(direction.x, direction.z) * target_speed, acceleration * delta)
	velocity.x = vel_2d.x
	velocity.z = vel_2d.y
	if not is_on_floor():
		velocity += get_gravity() * delta

	var look_direction := direction
	if state == State.ATTACK and not has_hit:
		look_direction = flat(player.global_position - global_position)
	if look_direction.length() > 0.01:
		var target_angle := atan2(look_direction.x, look_direction.z)
		model.global_rotation.y = lerp_angle(model.global_rotation.y, target_angle, turn_speed * delta)

func animation_logic() -> void:
	if state == State.ATTACK: return
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	anim_player.speed_scale = 1.0

	if ground_speed > 0.2:
		# Play the animation fast enough for the feet to keep up with the current speed
		play_animation("walk")
		anim_player.speed_scale = clampf(ground_speed / (NATURAL_WALK_SPEED * model.scale.x), 0.5, max_anim_speed)
	else:
		play_animation("idle")

func play_animation(anim_name: String) -> void:
	if anim_name == current_animation: return
	current_animation = anim_name
	if anim_name in REVERSED:
		anim_player.play(anim_name, 0.2, -1.0, true)
	else:
		anim_player.play(anim_name, 0.2)

func facing() -> Vector3:
	return flat(model.global_basis.z).normalized()

func distance_to(point: Vector3) -> float:
	return flat(point - global_position).length()

func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

# Each Mixamo file holds one animation called "mixamo_com"; copy them into the model's player
func load_animations() -> void:
	var library := anim_player.get_animation_library("")
	for anim_name in ANIMATIONS:
		if library.has_animation(anim_name): continue
		var source: Node = ANIMATIONS[anim_name].instantiate()
		var anim: Animation = source.get_node("AnimationPlayer").get_animation("mixamo_com").duplicate()
		source.free()
		anim.loop_mode = Animation.LOOP_LINEAR if anim_name in LOOPING else Animation.LOOP_NONE
		if anim_name == "walk":
			lock_hips_in_place(anim)
		library.add_animation(anim_name, anim)

# Removes the travel baked into the animation, the script is what moves the enemy
func lock_hips_in_place(anim: Animation) -> void:
	var track := anim.find_track(HIPS_TRACK, Animation.TYPE_POSITION_3D)
	if track == -1: return
	var start: Vector3 = anim.track_get_key_value(track, 0)
	for key in anim.track_get_key_count(track):
		var pos: Vector3 = anim.track_get_key_value(track, key)
		anim.track_set_key_value(track, key, Vector3(start.x, pos.y, start.z))
