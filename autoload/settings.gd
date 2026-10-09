extends Node

# The player's options: volume, camera sensitivity and fullscreen.
# They are saved to a file, so they are still there the next time the game opens.

const PATH := "user://settings.cfg"

# 0 is silent and 1 is full volume
var volume := 1.0
# Multiplies the camera speed; 1 is the normal speed
var sensitivity := 1.0
var fullscreen := true

func _ready() -> void:
	var file := ConfigFile.new()
	# No file yet means first run: keep the defaults and leave the window as the project set it
	if file.load(PATH) != OK: return
	set_volume(file.get_value("audio", "volume", volume))
	set_sensitivity(file.get_value("controls", "sensitivity", sensitivity))
	set_fullscreen(file.get_value("video", "fullscreen", fullscreen))

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))
	AudioServer.set_bus_mute(0, volume == 0.0)

func set_sensitivity(value: float) -> void:
	sensitivity = value

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "volume", volume)
	file.set_value("controls", "sensitivity", sensitivity)
	file.set_value("video", "fullscreen", fullscreen)
	file.save(PATH)
