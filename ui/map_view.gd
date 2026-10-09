extends Control

const ROOM_COLOR := Color(0.2, 0.24, 0.32)
const WALL_COLOR := Color(0.75, 0.8, 0.9)
const PLAYER_COLOR := Color(1.0, 0.85, 0.3)
const MARGIN := 90.0

# The level gives the rooms, the markers and the player through its get_map_* functions
var level: Node

func _draw() -> void:
	if level == null or not level.has_method("get_map_rooms"): return
	var rooms: Dictionary = level.get_map_rooms()
	var bounds: Rect2 = rooms.values()[0]
	for room in rooms.values():
		bounds = bounds.merge(room)
	# Fits the whole level on the screen: world x goes right, world z goes down
	var zoom: float = minf((size.x - MARGIN * 2.0) / bounds.size.x, (size.y - MARGIN * 2.0) / bounds.size.y)
	var origin: Vector2 = size / 2.0 - bounds.get_center() * zoom
	var font := ThemeDB.fallback_font

	for room_name in rooms:
		var room: Rect2 = rooms[room_name]
		var rect := Rect2(origin + room.position * zoom, room.size * zoom)
		draw_rect(rect, ROOM_COLOR)
		draw_rect(rect, WALL_COLOR, false, 3.0)
		draw_string(font, rect.position + Vector2(12, 30), room_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, WALL_COLOR)

	for marker in level.get_map_markers():
		var position_3d: Vector3 = marker["position"]
		var point := origin + Vector2(position_3d.x, position_3d.z) * zoom
		draw_circle(point, marker.get("radius", 8.0), marker["color"])
		if marker.has("label"):
			draw_string(font, point + Vector2(12, 6), marker["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, marker["color"])

	# The player is an arrow pointing where the dog faces
	var player: Node3D = level.get_map_player()
	var center := origin + Vector2(player.global_position.x, player.global_position.z) * zoom
	var angle: float = player.model.rotation.y
	var forward := Vector2(sin(angle), cos(angle))
	var side := Vector2(forward.y, -forward.x)
	draw_colored_polygon(PackedVector2Array([center + forward * 18.0, center - forward * 10.0 + side * 11.0, center - forward * 10.0 - side * 11.0]), PLAYER_COLOR)
