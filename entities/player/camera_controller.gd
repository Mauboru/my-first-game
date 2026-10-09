extends Node3D

@export var min_limit_x: float
@export var max_limit_x: float
@export var horizontal_acceleration := 2.0
@export var vertical_acceleration := 1.0
@export var mouse_acceleation := 0.005
@export var focus_turn_speed := 6.0

# While the player focuses on something the camera keeps this point (world space) ahead
var has_focus := false
var focus_point := Vector3.ZERO

func _process(delta: float) -> void:
	if has_focus:
		var to_point := focus_point - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-to_point.x, -to_point.z), focus_turn_speed * delta)
	var joy_dir = Input.get_vector("pan_left", "pan_right", "pan_up", "pan_down")
	rotate_from_vector(joy_dir * delta * Vector2(horizontal_acceleration, vertical_acceleration) * Settings.sensitivity)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_from_vector(event.relative * mouse_acceleation * Settings.sensitivity)

func rotate_from_vector(v: Vector2):
	if v.length() == 0: return
	rotation.y -= v.x
	rotation.x -= v.y
	rotation.x = clamp(rotation.x, min_limit_x, max_limit_x)
