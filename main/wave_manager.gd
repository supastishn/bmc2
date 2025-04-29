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
# --- NEW: Tracking active bloons ---
var active_bloons_in_current_round: int = 0
var spawning_complete_for_current_round: bool = false

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
	if current_wave_index >= len(current_wave_data): # Changed wave_index to current_wave_index
		print("All waves finished!"); return
	if current_wave_index >= len(current_wave_data):
		print("All waves finished!")
		return

	print("Starting Wave ", current_wave_index + 1)
	bloons_spawned_in_wave = 0
	# --- NEW: Prepare the flat list of bloons for the current wave ---
	# --- NEW: Reset tracking for the new wave ---
	active_bloons_in_current_round = 0 # Will be incremented as they spawn
	spawning_complete_for_current_round = false

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
	# Check if spawning for the current wave is actually finished
	if current_bloon_spawn_index >= bloons_in_wave.size():
		if not spawning_complete_for_current_round: # Only set flag once
			spawning_complete_for_current_round = true
			print("Wave ", current_wave_index + 1, " spawning finished.")
			_check_round_end() # Check if round ended exactly when spawning finished
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
	else:
		# This was the last bloon spawned, mark spawning as complete and check round end
		spawning_complete_for_current_round = true
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

	# --- NEW: Increment active bloon count ---
	active_bloons_in_current_round += 1
	# print_debug("Spawned bloon, active count: ", active_bloons_in_current_round)

	# --- Add to Scene and Configure ---
	# Assign stats directly. The pool_reset should handle applying them internally if needed.
	bloon_instance.stats = bloon_stats_resource

	path_node.add_child(bloon_instance)
	# --- NEW: Set progress ratio for children ---
	if p_progress_ratio > 0.0 and bloon_instance is PathFollow3D:
		bloon_instance.progress_ratio = p_progress_ratio

	# --- NEW: Connect child spawning signal ---
	if not bloon_instance.spawn_children_requested.is_connected(_on_bloon_spawn_children):
		bloon_instance.spawn_children_requested.connect(_on_bloon_spawn_children)
	# --- NEW: Connect bloon removal signal ---
	if not bloon_instance.bloon_removed_from_play.is_connected(_on_bloon_removed):
		bloon_instance.bloon_removed_from_play.connect(_on_bloon_removed)

	# The bloon's pool_reset() should handle setting progress to 0.
	# No further setup needed here unless you have wave-specific modifications.

# --- NEW: Handle Bloon Removal ---
func _on_bloon_removed():
	if active_bloons_in_current_round > 0:
		active_bloons_in_current_round -= 1
		# print_debug("Bloon removed, active count: ", active_bloons_in_current_round)
		_check_round_end()
	# else: print_debug("Bloon removed, but active count was already 0?") # Should not happen ideally

# --- NEW: Check if the Round Should End ---
func _check_round_end():
	# Round ends if spawning is complete AND no active bloons remain
	if spawning_complete_for_current_round and active_bloons_in_current_round == 0:
		print("All bloons cleared for wave ", current_wave_index + 1)
		GameManager.advance_round() # Tell GameManager round is over
		wave_timer.start() # Start timer for the *next* wave

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
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED, 1, null, 0, false, false)
	stats.bloon_type = "Red"
	# stats.is_fortified = false (default)
	# stats.is_regrow = false (default)
	# stats.immunities = [] (default)
	# stats.moab_class = false (default)
	return stats

func _get_blue_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.4, 1, _get_red_stats(), 1, false, false)
	stats.bloon_type = "Blue"
	return stats

func _get_green_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.8, 1, _get_blue_stats(), 1, false, false)
	stats.bloon_type = "Green"
	return stats

func _get_yellow_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 3.2, 1, _get_green_stats(), 1, false, false)
	stats.bloon_type = "Yellow"
	return stats

func _get_pink_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 3.5, 1, _get_yellow_stats(), 1, false, false)
	stats.bloon_type = "Pink"
	return stats

func _get_black_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.8, 1, _get_pink_stats(), 2, false, false)
	stats.bloon_type = "Black"
	stats.immunities = ["Explosive"]
	return stats

func _get_white_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 2.0, 1, _get_pink_stats(), 2, false, false)
	stats.bloon_type = "White"
	stats.immunities = ["Ice"]
	return stats

func _get_lead_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.0, 1, _get_black_stats(), 2, false, true)
	stats.bloon_type = "Lead"
	stats.immunities = ["Sharp"]
	return stats

func _get_zebra_stats() -> BloonStats:
	# Children handled specially in bloon.gd handle_pop
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.8, 1, null, 0, false, false)
	stats.bloon_type = "Zebra"
	stats.immunities = ["Explosive", "Ice"]
	return stats

func _get_rainbow_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 2.2, 1, _get_zebra_stats(), 2, false, false)
	stats.bloon_type = "Rainbow"
	return stats

func _get_purple_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 3.0, 1, _get_pink_stats(), 2, false, false)
	stats.bloon_type = "Purple"
	stats.immunities = ["Fire", "Plasma", "Energy"]
	return stats

func _get_ceramic_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(10, BASE_RED_SPEED * 2.5, 1, _get_rainbow_stats(), 2, false, false)
	stats.bloon_type = "Ceramic"
	return stats

func _get_moab_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(200, BASE_RED_SPEED * 1.0, 1, _get_ceramic_stats(), 4, false, false)
	stats.bloon_type = "MOAB"
	stats.moab_class = true
	return stats

func _get_bfb_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(700, BASE_RED_SPEED * 0.25, 1, _get_moab_stats(), 4, false, false)
	stats.bloon_type = "BFB"
	stats.moab_class = true
	return stats

func _get_zomg_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(4000, BASE_RED_SPEED * 0.18, 1, _get_bfb_stats(), 4, false, false)
	stats.bloon_type = "ZOMG"
	stats.moab_class = true
	return stats

func _get_ddt_stats() -> BloonStats:
	# Children need to be Camo Regrow Ceramics - handle this later if needed
	# For now, just regular Ceramics
	var child_stats = _get_ceramic_stats()
	child_stats.is_camo = true
	child_stats.is_regrow = true # Note: This mutates the result of _get_ceramic_stats. Better to create fresh if needed elsewhere.
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(400, BASE_RED_SPEED * 2.75, 1, child_stats, 4, true, true)
	stats.bloon_type = "DDT"
	stats.immunities = ["Sharp", "Explosive"] # Lead + Black properties
	stats.moab_class = true
	return stats

func _get_bad_stats() -> BloonStats:
	# Children handled specially in bloon.gd handle_pop
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(20000, BASE_RED_SPEED * 0.18, 1, null, 0, false, false)
	stats.bloon_type = "BAD"
	stats.moab_class = true
	return stats
#endregion
