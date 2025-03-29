# WaveManager.gd (Simplified Example)
extends Node

@export var bloon_scene: PackedScene
@export var path_node: Path3D # Assign your Path3D node here

@onready var spawn_timer: Timer = $SpawnTimer
@onready var wave_timer: Timer = $WaveTimer

var current_wave_data = [] # e.g., [{"type": "Red", "count": 10, "delay": 0.5}]
var wave_index = 0
var bloons_spawned_in_wave = 0

func _ready():
	# Setup timers (or create them via code)
	if not spawn_timer: # Create if not added in editor
		spawn_timer = Timer.new()
		spawn_timer.name = "SpawnTimer"
		spawn_timer.one_shot = false
		add_child(spawn_timer)
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	if not wave_timer: # Create if not added in editor
		wave_timer = Timer.new()
		wave_timer.name = "WaveTimer"
		wave_timer.wait_time = 5.0 # Time between waves
		wave_timer.one_shot = false
		add_child(wave_timer)
		wave_timer.timeout.connect(start_next_wave)

	# Load wave data (replace with your actual data loading)
	current_wave_data = [
		{"scene": bloon_scene, "count": 5, "delay": 1.0},
		{"scene": bloon_scene, "count": 10, "delay": 0.5} # Example second wave
	]
	start_next_wave()


func start_next_wave():
	if wave_index >= len(current_wave_data):
		print("All waves finished!")
		return

	print("Starting Wave ", wave_index + 1)
	bloons_spawned_in_wave = 0
	# Start spawning the first bloon of the current wave
	_on_spawn_timer_timeout()


func _on_spawn_timer_timeout():
	if wave_index >= len(current_wave_data): return # Should not happen if logic is right

	var wave_info = current_wave_data[wave_index]
	if bloons_spawned_in_wave < wave_info["count"]:
		spawn_bloon(wave_info["scene"])
		bloons_spawned_in_wave += 1
		# Start timer for the next bloon in this wave
		spawn_timer.wait_time = wave_info["delay"]
		spawn_timer.start()
	else:
		# Wave finished spawning, start timer for the next wave
		print("Wave ", wave_index + 1, " spawning complete.")
		wave_index += 1
		wave_timer.start()


func spawn_bloon(scene_to_spawn: PackedScene):
	if not path_node or not scene_to_spawn:
		printerr("Path node or Bloon scene not set in WaveManager!")
		return

	var bloon_instance = scene_to_spawn.instantiate()
	# IMPORTANT: Add the bloon as a child of the Path3D node
	# so the PathFollow3D automatically knows which path to follow.
	path_node.add_child(bloon_instance)
	# Bloon starts at progress = 0 automatically
