# File: res://main/wave_manager.gd
extends Node

# Preload the base bloon scene used for all types
@export var base_bloon_scene: PackedScene = preload("res://bloon/bloon.tscn")
const BLOON_STATS_SCRIPT = preload("res://stats/bloon_stats.gd")

@export var path_node: Path3D # Assign your Path3D node here

@onready var spawn_timer: Timer = $SpawnTimer
@onready var wave_timer: Timer = $WaveTimer

var current_wave_data = []
var current_wave_index = 0
var bloons_in_wave: Array[Dictionary] = [] # Holds {"stats_func": Callable, "delay": float}
var current_bloon_spawn_index: int = 0
var bloons_spawned_in_wave = 0

const BASE_RED_SPEED = 2.0 # Define base speed for multipliers

func _ready():
	# Ensure timers exist and connect signals
	if not spawn_timer: spawn_timer = Timer.new(); spawn_timer.name = "SpawnTimer"; add_child(spawn_timer)
	spawn_timer.one_shot = true # Spawn one bloon per timeout
	if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout): spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	if not wave_timer: wave_timer = Timer.new(); wave_timer.name = "WaveTimer"; add_child(wave_timer)
	wave_timer.wait_time = 5.0; wave_timer.one_shot = true # Time between waves
	if not wave_timer.timeout.is_connected(start_next_wave): wave_timer.timeout.connect(start_next_wave)

	# Example Wave Data Structure using stats functions
	# List of waves, where each wave is a list of bloon groups
	current_wave_data = [
		# Wave 1: 15 Red Bloons
		[ {"stats_func": _get_red_stats, "count": 15, "delay": 0.8} ],
		# Wave 2: 25 Blue Bloons
		[ {"stats_func": _get_blue_stats, "count": 25, "delay": 0.4} ],
		# Wave 3: 10 Red, 10 Blue
		[ {"stats_func": _get_red_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_blue_stats, "count": 10, "delay": 0.5} ]
	]
	start_next_wave()

func start_next_wave():
	if wave_index >= len(current_wave_data):
		print("All waves finished!"); return
	if current_wave_index >= len(current_wave_data):
		print("All waves finished!")
		return

	print("Starting Wave ", current_wave_index + 1)
	bloons_spawned_in_wave = 0
	# --- NEW: Prepare the flat list of bloons for the current wave ---
	bloons_in_wave.clear()
	var wave_groups = current_wave_data[current_wave_index]
	for group in wave_groups:
		var stats_func: Callable = group["stats_func"]
		var count: int = group["count"]
		var delay: float = group["delay"]
		for i in range(count):
			bloons_in_wave.append({"stats_func": stats_func, "delay": delay})

	current_bloon_spawn_index = 0
	_on_spawn_timer_timeout()


func _on_spawn_timer_timeout():
	if current_bloon_spawn_index >= bloons_in_wave.size():
		# This wave's spawning finished
		print("Wave ", current_wave_index + 1, " spawning complete.")
		current_wave_index += 1
		if current_wave_index < len(current_wave_data): # Check if there IS a next wave
			wave_timer.start() # Start inter-wave timer
		else:
			print("Final wave spawning complete!")
		return

	# Spawn the next bloon in the list
	var bloon_info = bloons_in_wave[current_bloon_spawn_index]
	var stats_func: Callable = bloon_info["stats_func"]
	var bloon_stats: BloonStats = stats_func.call() # Call the function to get stats
	spawn_bloon(bloon_stats)
	current_bloon_spawn_index += 1

	# Schedule next spawn (if there is one)
	if current_bloon_spawn_index < bloons_in_wave.size():
		spawn_timer.wait_time = bloon_info["delay"] # Use delay from the bloon just spawned
		spawn_timer.start()


	# This else block might be redundant now due to the check at the start
	# else:
		# Wave finished spawning, start timer for the next wave
		# print("Wave ", wave_index + 1, " spawning complete.")
		# wave_index += 1
		# wave_timer.start()


func spawn_bloon(bloon_stats_resource: BloonStats, p_progress_ratio: float = 0.0):
	if not path_node: printerr("Path node not set in WaveManager!"); return
	if not base_bloon_scene: printerr("Base Bloon Scene not set in WaveManager!"); return
	if not bloon_stats_resource or not bloon_stats_resource is BloonStats:
		printerr("Invalid BloonStats resource provided to spawn_bloon!")
		return

	# --- Request Bloon from Pool ---
	# We always use the base scene, the stats resource defines the type
	var bloon_instance: Node = NodePoolManager.request_node(base_bloon_scene)
	if not bloon_instance:
		printerr("WaveManager failed to get bloon from pool/fallback!")
		return # Failed to get a bloon

	# --- Add to Scene and Configure ---
	# IMPORTANT: Add to the Path3D node *before* configuring PathFollow specifics
	path_node.add_child(bloon_instance)

	# The bloon's pool_reset() should handle setting progress to 0.
	# No further setup needed here unless you have wave-specific modifications.
