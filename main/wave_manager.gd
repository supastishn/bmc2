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


func spawn_bloon(bloon_stats_resource: BloonStats, p_progress_ratio: float = 0.0): # Added progress ratio param
	if not path_node: printerr("Path node not set in WaveManager!"); return
	if not base_bloon_scene: printerr("Base Bloon Scene not set in WaveManager!"); return
	if not bloon_stats_resource or not bloon_stats_resource is BloonStats: # Check type
		printerr("Invalid BloonStats resource provided to spawn_bloon!")
		return

	# --- Request Bloon from Pool ---
	# We always use the base scene, the stats resource defines the type
	var bloon_instance: Node = NodePoolManager.request_node(base_bloon_scene) # Changed type hint
	if not bloon_instance:
		printerr("WaveManager failed to get bloon from pool/fallback!")
		return # Failed to get a bloon

	# --- Add to Scene and Configure ---
	# Set stats *before* adding to path? pool_reset should handle internal state.
	if bloon_instance.has_method("set_stats"): # Assume bloon.gd has set_stats if needed
		bloon_instance.stats = bloon_stats_resource # Directly assign the stats resource
	else:
		printerr("Bloon instance is missing set_stats method!") # Should not happen if using pool_reset correctly

	path_node.add_child(bloon_instance)
	# --- NEW: Set progress ratio for children ---
	if p_progress_ratio > 0.0 and bloon_instance is PathFollow3D:
		bloon_instance.progress_ratio = p_progress_ratio

	# --- NEW: Connect child spawning signal ---
	if not bloon_instance.spawn_children_requested.is_connected(_on_bloon_spawn_children):
		bloon_instance.spawn_children_requested.connect(_on_bloon_spawn_children)

	# The bloon's pool_reset() should handle setting progress to 0.
	# No further setup needed here unless you have wave-specific modifications.


# --- NEW: Child Spawning Handler ---
func _on_bloon_spawn_children(children_stats_array: Array, spawn_progress_ratio: float):
	for child_stats in children_stats_array:
		if child_stats is BloonStats:
			spawn_bloon(child_stats, spawn_progress_ratio)
		else:
			printerr("Invalid child stats received in _on_bloon_spawn_children: ", child_stats)

#endregion Factory Functions


#region Bloon Stat Functions
# --- Bloon Stat Definition Functions ---

func _get_red_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		1, BASE_RED_SPEED, 1, null, 0, false, false, "Red", false, false, [], false
	)

func _get_blue_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		1, BASE_RED_SPEED * 1.4, 1, _get_red_stats(), 1, false, false, "Blue", false, false, [], false
	)

func _get_green_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		1, BASE_RED_SPEED * 1.8, 1, _get_blue_stats(), 1, false, false, "Green", false, false, [], false
	)

func _get_yellow_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		1, BASE_RED_SPEED * 3.2, 1, _get_green_stats(), 1, false, false, "Yellow", false, false, [], false
	)

func _get_pink_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		1, BASE_RED_SPEED * 3.5, 1, _get_yellow_stats(), 1, false, false, "Pink", false, false, [], false
	)

func _get_black_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		1, BASE_RED_SPEED * 1.8, 1, _get_pink_stats(), 2, false, false, "Black", false, false, ["Explosive"], false
	)

func _get_white_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		1, BASE_RED_SPEED * 2.0, 1, _get_pink_stats(), 2, false, false, "White", false, false, ["Ice"], false
	)

func _get_lead_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		1, BASE_RED_SPEED * 1.0, 1, _get_black_stats(), 2, false, true, "Lead", false, false, ["Sharp"], false
	)

func _get_zebra_stats() -> BloonStats:
	# Children handled specially in bloon.gd handle_pop
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		1, BASE_RED_SPEED * 1.8, 1, null, 0, false, false, "Zebra", false, false, ["Explosive", "Ice"], false
	)

func _get_rainbow_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		1, BASE_RED_SPEED * 2.2, 1, _get_zebra_stats(), 2, false, false, "Rainbow", false, false, [], false
	)

func _get_purple_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		1, BASE_RED_SPEED * 3.0, 1, _get_pink_stats(), 2, false, false, "Purple", false, false, ["Fire", "Plasma", "Energy"], false
	)

func _get_ceramic_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		10, BASE_RED_SPEED * 2.5, 1, _get_rainbow_stats(), 2, false, false, "Ceramic", false, false, [], false
	)

func _get_moab_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		200, BASE_RED_SPEED * 1.0, 1, _get_ceramic_stats(), 4, false, false, "MOAB", false, false, [], true
	)

func _get_bfb_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		700, BASE_RED_SPEED * 0.25, 1, _get_moab_stats(), 4, false, false, "BFB", false, false, [], true
	)

func _get_zomg_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		4000, BASE_RED_SPEED * 0.18, 1, _get_bfb_stats(), 4, false, false, "ZOMG", false, false, [], true
	)

func _get_ddt_stats() -> BloonStats:
	# Children need to be Camo Regrow Ceramics - handle this later if needed
	# For now, just regular Ceramics
	var child_ceramic_stats = _get_ceramic_stats()
	child_ceramic_stats.is_camo = true
	child_ceramic_stats.is_regrow = true # Note: Need to ensure BloonStats supports mutation or create a dedicated function
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		400, BASE_RED_SPEED * 2.75, 1, child_ceramic_stats, 4, true, true, "DDT", false, false, ["Sharp", "Explosive"], true
	)

func _get_bad_stats() -> BloonStats:
	# Children handled specially in bloon.gd handle_pop
	# health, speed, cash, child_stats, child_count, camo, lead, type, fortified, regrow, immunities, moab
	return BloonStats.new(
		20000, BASE_RED_SPEED * 0.18, 1, null, 0, false, false, "BAD", false, false, [], true
	)
#endregion

