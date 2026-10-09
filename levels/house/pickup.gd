extends Area3D

signal collected(task_id: String)

@export var task_id := ""
@export var spin_speed := 2.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	rotate_y(spin_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	collected.emit(task_id)
	queue_free()
