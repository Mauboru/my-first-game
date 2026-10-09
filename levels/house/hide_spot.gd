extends Area3D

# While the player is inside, enemies cannot see it

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.is_hidden = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.is_hidden = false
