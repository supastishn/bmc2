# File: res://main/WaveManager.gd
extends Node

# Preload scenes that might be used in waves
# Example - replace with your actual bloon scene(s)
@export var default_bloon_scene: PackedScene = preload("res://bloon/bloon.tscn")

@export var path_node: Path3D # Assign your Path3D node here

@onready var spawn_timer: Timer = $SpawnTimer
@onready var wave_timer: Timer = $WaveTimer

var current_wave_data = []
var wave_index = 0
var bloons_spawned_in_wave = 0

func _ready():
	# Ensure timers exist and connect signals
	if not spawn_timer: spawn_timer = Timer.new(); spawn_timer.name = "SpawnTimer"; add_child(spawn_timer)
	spawn_timer.one_shot = true # Spawn one bloon per timeout
	if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout): spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	if not wave_timer: wave_timer = Timer.new(); wave_timer.name = "WaveTimer"; add_child(wave_timer)
	wave_timer.wait_time = 5.0; wave_timer.one_shot = true # Time between waves
	if not wave_timer.timeout.is_connected(start_next_wave): wave_timer.timeout.connect(start_next_wave)

	# Example Wave Data - Load your actual wave definitions here
	# Reference scenes directly now instead of just export var
	current_wave_data = [
		{"scene": default_bloon_scene, "count": 15, "delay": 0.8},
		{"scene": default_bloon_scene, "count": 25, "delay": 0.4}
		# Add more waves with different scenes as needed
		# {"scene": preload("res://bloon/blue_bloon.tscn"), "count": 10, "delay": 0.5}
	]
	start_next_wave()

func start_next_wave():
	if wave_index >= len(current_wave_data):
		print("All waves finished!"); return

	print("Starting Wave ", wave_index + 1)
	bloons_spawned_in_wave = 0
	# Trigger the first spawn of the wave immediately
	_on_spawn_timer_timeout()


func _on_spawn_timer_timeout():
	if wave_index >= len(current_wave_data): return

	var wave_info = current_wave_data[wave_index]
	if bloons_spawned_in_wave < wave_info["count"]:
		# Spawn using the scene defined in the wave data
		spawn_bloon(wave_info["scene"])
		bloons_spawned_in_wave += 1

		# Schedule next spawn in this wave (if not the last one)
		if bloons_spawned_in_wave < wave_info["count"]:
			spawn_timer.wait_time = wave_info["delay"]
			spawn_timer.start()
		else:
			# This wave's spawning finished, schedule next wave
			print("Wave ", wave_index + 1, " spawning complete.")
			wave_index += 1
			if wave_index < len(current_wave_data): # Check if there IS a next wave
				wave_timer.start() # Start inter-wave timer
			else:
				print("Final wave spawning complete!")


	# This else block might be redundant now due to check above
	# else:
		# Wave finished spawning, start timer for the next wave
		# print("Wave ", wave_index + 1, " spawning complete.")
		# wave_index += 1
		# wave_timer.start()


func spawn_bloon(scene_to_spawn: PackedScene):
	if not path_node: printerr("Path node not set in WaveManager!"); return
	if not scene_to_spawn: printerr("Invalid scene provided to spawn_bloon!"); return

	# --- Request Bloon from Pool ---
	var bloon_instance = NodePoolManager.request_node(scene_to_spawn)
	if not bloon_instance:
		printerr("WaveManager failed to get bloon from pool/fallback!")
		return # Failed to get a bloon

	# --- Add to Scene and Configure ---
	# IMPORTANT: Add to the Path3D node *before* configuring PathFollow specifics
	path_node.add_child(bloon_instance)

	# The bloon's pool_reset() should handle setting progress to 0.
	# No further setup needed here unless you have wave-specific modifications.
