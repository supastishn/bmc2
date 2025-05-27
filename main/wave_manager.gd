# File: res://main/wave_manager.gd
extends Node

signal wave_spawning_complete(round_number: int)
signal wave_cleared(round_number: int)

@export var base_bloon_scene: PackedScene = preload("res://bloon/bloon.tscn")
@export var inter_wave_delay: float = 3.0  # seconds to wait before next wave
# replace STATS_FUNC_MAP usage with BloonFactory
# remove: const BLOON_STATS_SCRIPT = preload("…")
# add:
# no preload needed if you autoload it; otherwise:
# const BloonFactory = preload("res://stats/bloon_factory.gd")

var path_node: Path3D # This will be set by main.gd

@onready var spawn_timer: Timer = Timer.new()
#@onready var wave_timer: Timer = $WaveTimer # Removed - waves advance immediately after spawning finishes

## Short‐hand loader (now a dict keyed by string round numbers)
var raw_wave_data: Dictionary = {}
var current_wave_data: Array = []

var current_wave_index = 0
var bloons_in_wave: Array[Dictionary] = [] # Holds {"stats_func": Callable, "delay": float}
var current_bloon_spawn_index: int = 0
var bloons_spawned_in_wave = 0
# --- NEW: Tracking active bloons ---
var active_bloons_in_current_round: int = 0
var spawning_complete_for_current_round: bool = false

#const BASE_RED_SPEED = 2.0 # Define base speed for multipliers

func _ready():
	# Ensure spawn_timer is in the tree before we ever start it
	if not spawn_timer.is_inside_tree():
		spawn_timer = Timer.new()
		spawn_timer.name = "SpawnTimer"
		spawn_timer.one_shot = true
		add_child(spawn_timer)

	if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout): spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	# -- load and expand shorthand wave data --
	var f = FileAccess.open("res://data/waves.json", FileAccess.READ)
	if f:
		var txt = f.get_as_text()
		f.close()
		var json = JSON.new()
		var j = json.parse(txt)
		if j == OK:
			raw_wave_data = json.data        # now a Dictionary keyed by "1"… "140"
			# build current_wave_data in numeric order
			var round_nums = raw_wave_data.keys().map(func(k): return int(k))
			round_nums.sort()
			for num in round_nums:
				var entries = raw_wave_data[str(num)]
				var conv: Array = []
				for entry in entries:
					var parts = entry.split(",")
					var key = parts[0].strip_edges().to_lower()
					var cnt = int(parts[1])
					var dly = float(parts[2])
					var fn = BloonFactory.STAT_FUNC_MAP.get(key)
					if fn:
						conv.append({ "stats_func": fn, "count": cnt, "delay": dly })
					else:
						printerr("WaveManager: unknown key '", key, "' in data round ", num)
				current_wave_data.append(conv)
		else:
			printerr("WaveManager: JSON parse error ", j.error)
	else:
		printerr("WaveManager: cannot open data/waves.json")
	# -- end load --


func start_next_wave():
	# --- Advance Round Number ---
	GameManager.advance_round() # Advance round counter for the wave *about* to start
	# Adjust wave starting logic if necessary - assuming current_wave_index maps 0-based
	print("Attempting to start wave for index: ", current_wave_index)
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
	# +1 is needed because size is 1 based, index is 0 based
	if current_bloon_spawn_index + 1 >= bloons_in_wave.size():
		if not spawning_complete_for_current_round:
			spawning_complete_for_current_round = true
			print("Wave ", current_wave_index + 1, " spawning finished.")
			emit_signal("wave_spawning_complete", current_wave_index + 1)

			_check_round_clear()   # ← NEW – covers case where all bloons were already popped
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


func spawn_bloon(bloon_stats_resource: BloonStats, p_progress_ratio: float = 0.0, immune_to_projectile: Object = null): # Added progress ratio and immunity params
	if not path_node: printerr("Path node not set in WaveManager!"); return
	if not base_bloon_scene: printerr("Base Bloon Scene not set in WaveManager!"); return
	# print_debug("Spawning %s at ratio %.2f, immune to %s" % [bloon_stats_resource.bloon_type, p_progress_ratio, immune_to_projectile]) # Debug
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
	# NEW: Initialize the bloon with the correct stats using the dedicated method
	if bloon_instance.has_method("initialize_with_stats"):
		bloon_instance.initialize_with_stats(bloon_stats_resource, immune_to_projectile) # Pass immunity
	else:
		printerr("Bloon instance %s is missing initialize_with_stats method!" % bloon_instance.name)
		# Handle error: Free the instance and decrement count
		if is_instance_valid(bloon_instance): bloon_instance.queue_free()
		active_bloons_in_current_round -=1
		return

	# Add to scene *before* setting progress ratio or connecting signals
	path_node.add_child(bloon_instance)

	# --- NEW: Set progress ratio for children ---
	if bloon_instance is PathFollow3D: # REMOVED: p_progress_ratio > 0.0 check
		bloon_instance.progress_ratio = p_progress_ratio

	# --- Always (re)connect child‐spawn and removal signals with our WaveManager as target ---
	bloon_instance.spawn_children_requested .connect( Callable(self, "_on_bloon_spawn_children") )
	bloon_instance.bloon_removed_from_play    .connect( Callable(self, "_on_bloon_removed") )

	# The bloon's pool_reset() should handle setting progress to 0.
	# No further setup needed here unless you have wave-specific modifications.

# --- NEW: Handle Bloon Removal ---
func _on_bloon_removed():
	# DEBUG log each removal
	print("DEBUG: Bloon removed, active before = ", active_bloons_in_current_round)
	if active_bloons_in_current_round > 0:
		active_bloons_in_current_round -= 1
		_check_round_clear() # Check if the field is now clear
	# else: print_debug("Bloon removed, but active count was already 0?") # Should not happen ideally

# --- NEW: Check if the Round Should End ---
# --- RENAMED: Check if the Round *field* is clear ---
func _check_round_clear():
	print('Check clear')
	
	# Field is clear if spawning is done AND there are no active bloons
	if spawning_complete_for_current_round and active_bloons_in_current_round == 0:
		await get_tree().process_frame
		print("DEBUG: Round ended – all bloons cleared for wave ", current_wave_index + 1)
		emit_signal("wave_cleared", current_wave_index + 1)

		# Advance to the next wave so the next “Start Wave” press loads it
		current_wave_index += 1

# --- NEW: Child Spawning Handler ---
func _on_bloon_spawn_children(children_stats_array: Array, spawn_progress_ratio: float, popping_projectile: Object): # Added popping_projectile param
	for child_stats in children_stats_array:
		if child_stats is BloonStats:
			spawn_bloon(child_stats, spawn_progress_ratio, popping_projectile) # Pass projectile for immunity
		else:
			printerr("Invalid child stats received in _on_bloon_spawn_children: ", child_stats)

#endregion Factory Functions
