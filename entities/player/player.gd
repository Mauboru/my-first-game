extends CharacterBody3D

signal barked(noise_position: Vector3)
signal attacked(combo_step: int)
signal interacted

@export var jump_height : float = 2.0
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.3

@onready var jump_velocity: float = (2.0 * jump_height) / jump_time_to_peak
@onready var jump_gravity: float = (2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
@onready var fall_gravity: float = (2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)

@export var based_speed := 5.0
@export var run_speed := 9.0
@export var sneak_speed := 1.3
@export var sneak_height := 0.72
@export var acceleration := 30.0
@export var deceleration := 40.0
@export var air_control := 0.4

@export var turn_speed := 10.0
@export var max_anim_speed := 3.0

@export var bark_cooldown := 1.5

@export var attack_anim_speed := 1.3
@export var evade_anim_speed := 2.2
@export var evade_distance := 5.0
@export var interact_anim_speed := 1.5
@export var sword_size := 0.6

@onready var bark_audio: AudioStreamPlayer3D = $Latido
@onready var footsteps = $Passos
@onready var camera = $CameraController/Camera3D
@onready var model = $Model
@onready var anim_player: AnimationPlayer = $Model/AnimationPlayer
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var capsule: CapsuleShape3D = collision_shape.shape
@onready var stand_height: float = capsule.height

const ANIMATIONS := {
	"idle": preload("res://entities/player/animations/idle.fbx"),
	"walk": preload("res://entities/player/animations/walk.fbx"),
	"run": preload("res://entities/player/animations/run.fbx"),
	"jump": preload("res://entities/player/animations/jump.fbx"),
	"flip": preload("res://entities/player/animations/flip.fbx"),
	"bark": preload("res://entities/player/animations/bark.fbx"),
	"attack": preload("res://entities/player/animations/attack.fbx"),
	"evade": preload("res://entities/player/animations/evade.fbx"),
	"interact": preload("res://entities/player/animations/interact.fbx"),
	"draw": preload("res://entities/player/animations/withdrawing_sword.fbx"),
	"sheathe": preload("res://entities/player/animations/sheathing_sword.fbx"),
}
const SWORD := preload("res://entities/player/sword.tscn")
const BARK_SOUNDS: Array[AudioStream] = [
	preload("res://entities/player/audio/bark1.mp3"),
	preload("res://entities/player/audio/bark2.mp3"),
	preload("res://entities/player/audio/bark3.mp3"),
]
const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"
# These animations include the take-off and the landing; only the airborne part (start, end) is used
const AIR_SECTIONS := {
	"jump": Vector2(0.5, 1.05),
	"flip": Vector2(0.3, 0.9),
}

# Ground speed (m/s) the feet cover when each animation plays at normal speed, with the model at scale 72
const NATURAL_SPEED := {
	"walk": 1.33,
	"run": 2.12,
}

# How much (m) an animation is lifted so the paws do not sink into the floor
const GROUND_OFFSET := {
	"walk": 0.2,
}

# Animations that play once, as an action that blocks the normal movement
const ONE_SHOT := ["attack", "evade", "interact", "draw", "sheathe"]
# attack.fbx holds three strikes in a row; each press of the attack button plays the next one (start, end)
const COMBO_SECTIONS: Array[Vector2] = [Vector2(0.35, 1.27), Vector2(1.27, 2.13), Vector2(2.13, 3.0)]
# The part of interact.fbx where the hand actually reaches out
const INTERACT_SECTION := Vector2(0.45, 2.7)
const SWORD_ANIM_SPEED := 1.5
# Moment of each sword animation when the hand is on the scabbard at the left hip
const DRAW_GRAB_TIME := 0.62
const SHEATHE_RELEASE_TIME := 1.25
# Direction (x, z in model space) the evade animation rolls towards
const EVADE_TRAVEL := Vector2(-1.33, -1.04)

var movement_input := Vector2.ZERO
var is_running := false
var is_sneaking := false
var is_hidden := false
var current_animation := ""
var can_double_jump := true
var air_animation := "jump"
var bark_left := 0.0
var bark_animation_left := 0.0
# Current blocking action: "", "draw", "sheathe", "attack", "evade" or "interact"
var action := ""
var action_time := 0.0
var action_left := 0.0
var action_speed := 1.0
var combo_step := 0
var attack_buffered := false
var sword_drawn := false
var evade_velocity := Vector2.ZERO
var sword_in_hand: Node3D
var sword_on_hip: Node3D

func _ready() -> void:
	load_animations()
	setup_sword()

func _physics_process(delta: float) -> void:
	action_logic(delta)
	jump_logic(delta)
	move_logic(delta)
	move_and_slide()
	animation_logic()
	bark_logic(delta)
	# Sneaking makes no noise
	if not is_sneaking:
		footsteps.step_logic(delta)

# Barking makes a noise that whoever is listening can go check
func bark_logic(delta: float) -> void:
	bark_left -= delta
	bark_animation_left -= delta
	if bark_left > 0.0 or not Input.is_action_just_pressed("bark"): return
	bark_left = bark_cooldown
	bark_audio.stream = BARK_SOUNDS.pick_random()
	bark_audio.play()
	bark_animation_left = anim_player.get_animation("bark").length
	if current_animation == "bark":
		anim_player.seek(0.0)
	barked.emit(global_position)

func move_logic(delta) -> void:
	movement_input = Input.get_vector("left", "right", "forward", "backward").rotated(-camera.global_rotation.y)
	var vel_2d = Vector2(velocity.x, velocity.z)
	is_running = Input.is_action_pressed("run")
	if action == "" and Input.is_action_just_pressed("sneak"):
		set_sneaking(not is_sneaking)
	
	var speed = run_speed if is_running else based_speed
	if is_sneaking:
		speed = sneak_speed
	var target_vel = movement_input * speed
	# Actions hold the player in place, except the evade, which rolls it away
	if action == "evade":
		target_vel = evade_velocity
	elif action != "":
		target_vel = Vector2.ZERO

	var accel = acceleration if movement_input != Vector2.ZERO else deceleration
	if not is_on_floor():
		accel *= air_control

	vel_2d = vel_2d.move_toward(target_vel, accel * delta)
	velocity.x = vel_2d.x
	velocity.z = vel_2d.y

	if action == "" and movement_input != Vector2.ZERO:
		var target_angle = atan2(movement_input.x, movement_input.y)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, turn_speed * delta)

# The collision shrinks while sneaking so the dog fits under furniture
func set_sneaking(value: bool) -> void:
	if not value and not can_stand_up(): return
	is_sneaking = value
	capsule.height = sneak_height if is_sneaking else stand_height
	collision_shape.position.y = capsule.height / 2.0

func can_stand_up() -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = capsule.radius * 0.9
	shape.height = stand_height - 0.1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * (stand_height / 2.0 + 0.05))
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func jump_logic(delta) -> void:
	if is_on_floor():
		can_double_jump = true
		air_animation = "jump"
		if action == "" and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		if can_double_jump and Input.is_action_just_pressed("jump"):
			can_double_jump = false
			air_animation = "flip"
			velocity.y = jump_velocity
		var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
		velocity.y -= gravity * delta

# Sword, attack combo, evade and interact: one at a time, each plays its animation to the end
func action_logic(delta: float) -> void:
	if action != "":
		action_time += delta
		action_left -= delta
		if action == "draw" and action_time * action_speed >= DRAW_GRAB_TIME:
			show_sword(true)
		elif action == "sheathe" and action_time * action_speed >= SHEATHE_RELEASE_TIME:
			show_sword(false)
		if action == "attack" and Input.is_action_just_pressed("attack"):
			attack_buffered = true
		# An attack can be cancelled into an evade
		if action == "attack" and Input.is_action_just_pressed("evade"):
			start_evade()
		elif action_left <= 0.0:
			finish_action()
		return

	if not is_on_floor() or is_sneaking: return
	if Input.is_action_just_pressed("attack"):
		if sword_drawn:
			start_attack(0)
		else:
			# The first press draws the sword and then strikes
			attack_buffered = true
			start_action("draw", Vector2(0.0, anim_player.get_animation("draw").length), SWORD_ANIM_SPEED)
	elif Input.is_action_just_pressed("evade"):
		start_evade()
	elif Input.is_action_just_pressed("interact"):
		start_action("interact", INTERACT_SECTION, interact_anim_speed)
		interacted.emit()
	elif Input.is_action_just_pressed("sword"):
		var anim_name := "sheathe" if sword_drawn else "draw"
		start_action(anim_name, Vector2(0.0, anim_player.get_animation(anim_name).length), SWORD_ANIM_SPEED)

# Plays one stretch (start, end) of the animation with the same name as the action
func start_action(action_name: String, section: Vector2, speed: float) -> void:
	action = action_name
	action_time = 0.0
	action_speed = speed
	action_left = (section.y - section.x) / speed
	current_animation = action_name
	anim_player.speed_scale = 1.0
	anim_player.play_section(action_name, section.x, section.y, 0.15, speed)
	anim_player.seek(section.x)

func finish_action() -> void:
	var finished := action
	action = ""
	current_animation = ""
	if finished == "draw":
		sword_drawn = true
	elif finished == "sheathe":
		sword_drawn = false
	show_sword(sword_drawn)

	# A press during a strike chains into the next one; after the third the combo starts over
	var chain := attack_buffered and sword_drawn and finished in ["draw", "attack"]
	attack_buffered = false
	if chain:
		start_attack((combo_step + 1) % COMBO_SECTIONS.size() if finished == "attack" else 0)

func start_attack(step: int) -> void:
	combo_step = step
	if movement_input != Vector2.ZERO:
		model.rotation.y = atan2(movement_input.x, movement_input.y)
	start_action("attack", COMBO_SECTIONS[step], attack_anim_speed)
	attacked.emit(step)

# Rolls towards where the player is pushing, or backwards when standing still
func start_evade() -> void:
	var direction := movement_input.normalized()
	if direction == Vector2.ZERO:
		direction = -Vector2(sin(model.rotation.y), cos(model.rotation.y))
	attack_buffered = false
	start_action("evade", Vector2(0.0, anim_player.get_animation("evade").length), evade_anim_speed)
	evade_velocity = direction * evade_distance / action_left
	# Turns the model so the roll in the animation goes the same way the player moves
	model.rotation.y = atan2(direction.x, direction.y) - atan2(EVADE_TRAVEL.x, EVADE_TRAVEL.y)

# Two swords follow the skeleton, one in the right hand and one on the left hip; only one shows at a time
func setup_sword() -> void:
	var skeleton: Skeleton3D = $Model/Skeleton3D
	# Positions and directions as seen on the T-pose: x is the dog's left, z is forward (meters)
	sword_in_hand = attach_sword(skeleton, "mixamorig_RightHand", Vector3(-0.09, -0.02, 0.0), Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN))
	var blade_down := Vector3(0.0, -0.86, -0.5).normalized()
	sword_on_hip = attach_sword(skeleton, "mixamorig_Hips", Vector3(0.17, 0.0, 0.0), Basis(blade_down.cross(Vector3.RIGHT), blade_down, Vector3.RIGHT))
	show_sword(false)

func attach_sword(skeleton: Skeleton3D, bone_name: String, offset: Vector3, direction: Basis) -> Node3D:
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone_name))
	var attachment := BoneAttachment3D.new()
	skeleton.add_child(attachment)
	attachment.bone_name = bone_name
	var sword: Node3D = SWORD.instantiate()
	attachment.add_child(sword)
	# The skeleton lives inside the scaled model, so meters are converted to its units
	var unit: float = 1.0 / model.scale.x
	var wanted := Transform3D(direction.scaled(Vector3.ONE * sword_size * unit), rest.origin + offset * unit)
	sword.transform = rest.affine_inverse() * wanted
	return sword

func show_sword(in_hand: bool) -> void:
	sword_in_hand.visible = in_hand
	sword_on_hip.visible = not in_hand

func animation_logic() -> void:
	if action != "":
		bark_animation_left = 0.0
		return
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	anim_player.speed_scale = 1.0
	
	if not is_on_floor():
		play_animation(air_animation)
	elif is_sneaking:
		# Stays in the crouched pose when stopped, frozen on the current frame
		play_animation("walk")
		anim_player.speed_scale = minf(ground_speed / NATURAL_SPEED["walk"], max_anim_speed)
	elif ground_speed > 0.1:
		# Play the animation fast enough for the feet to keep up with the current speed
		play_animation("run")
		anim_player.speed_scale = clampf(ground_speed / NATURAL_SPEED["run"], 0.5, max_anim_speed)
	elif bark_animation_left > 0.0:
		play_animation("bark")
	else:
		play_animation("idle")
	# Moving, jumping or sneaking cuts the bark animation short
	if current_animation != "bark":
		bark_animation_left = 0.0

func play_animation(anim_name: String) -> void:
	if anim_name == current_animation: return
	current_animation = anim_name
	if AIR_SECTIONS.has(anim_name):
		var section: Vector2 = AIR_SECTIONS[anim_name]
		var air_time := jump_time_to_peak + jump_time_to_descent
		anim_player.play(anim_name, 0.1, (section.y - section.x) / air_time)
		anim_player.seek(section.x)
	else:
		anim_player.play(anim_name, 0.2)

# Each Mixamo file holds one animation called "mixamo_com"; copy them into the model's player
func load_animations() -> void:
	var library := anim_player.get_animation_library("")
	for anim_name in ANIMATIONS:
		if library.has_animation(anim_name): continue
		var source: Node = ANIMATIONS[anim_name].instantiate()
		var anim: Animation = source.get_node("AnimationPlayer").get_animation("mixamo_com").duplicate()
		source.free()
		var is_air_anim := AIR_SECTIONS.has(anim_name)
		var plays_once: bool = is_air_anim or anim_name in ONE_SHOT
		anim.loop_mode = Animation.LOOP_NONE if plays_once else Animation.LOOP_LINEAR
		lock_hips_in_place(anim, is_air_anim)
		if GROUND_OFFSET.has(anim_name):
			lift_hips(anim, GROUND_OFFSET[anim_name] / model.scale.y)
		if is_air_anim:
			anim.length = AIR_SECTIONS[anim_name].y
		library.add_animation(anim_name, anim)

# Removes the travel baked into the animation, the script is what moves the player
func lock_hips_in_place(anim: Animation, lock_height := false) -> void:
	var track := anim.find_track(HIPS_TRACK, Animation.TYPE_POSITION_3D)
	if track == -1: return
	var start: Vector3 = anim.track_get_key_value(track, 0)
	for key in anim.track_get_key_count(track):
		var pos: Vector3 = anim.track_get_key_value(track, key)
		var height := minf(pos.y, start.y) if lock_height else pos.y
		anim.track_set_key_value(track, key, Vector3(start.x, height, start.z))

func lift_hips(anim: Animation, height: float) -> void:
	var track := anim.find_track(HIPS_TRACK, Animation.TYPE_POSITION_3D)
	if track == -1: return
	for key in anim.track_get_key_count(track):
		var pos: Vector3 = anim.track_get_key_value(track, key)
		anim.track_set_key_value(track, key, pos + Vector3.UP * height)
