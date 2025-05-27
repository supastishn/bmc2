# File: res://main/wave_manager.gd
extends Node

signal wave_spawning_complete(round_number: int)
signal wave_cleared(round_number: int)

@export var base_bloon_scene: PackedScene = preload("res://bloon/bloon.tscn")
@export var inter_wave_delay: float = 3.0  # seconds to wait before next wave
const BLOON_STATS_SCRIPT = preload("res://stats/bloon_stats.gd")

var path_node: Path3D # This will be set by main.gd

@onready var spawn_timer: Timer = Timer.new()
#@onready var wave_timer: Timer = $WaveTimer # Removed - waves advance immediately after spawning finishes

## Short‐hand loader (now a dict keyed by string round numbers)
var raw_wave_data: Dictionary = {}
var current_wave_data: Array = []

var STATS_FUNC_MAP = {
  "red": _get_red_stats,   "blue": _get_blue_stats,
  "green": _get_green_stats, "yellow": _get_yellow_stats,
  "pink": _get_pink_stats, "black": _get_black_stats,
  "white": _get_white_stats, "lead": _get_lead_stats,
  "zebra": _get_zebra_stats, "rainbow": _get_rainbow_stats,
  "purple": _get_purple_stats, "ceramic": _get_ceramic_stats,
  "moab": _get_moab_stats, "bfb": _get_bfb_stats,
  "zomg": _get_zomg_stats, "ddt": _get_ddt_stats,
  "bad": _get_bad_stats,

  # --- FORTIFIED variants ---
  "fortified_lead":   _get_fortified_lead_stats,
  "fortified_ceramic":_get_fortified_ceramic_stats,
  "fortified_moab":   _get_fortified_moab_stats,
  "fortified_bfb":    _get_fortified_bfb_stats,
  "fortified_zomg":   _get_fortified_zomg_stats,
  "fortified_ddt":    _get_fortified_ddt_stats,
  "fortified_bad":    _get_fortified_bad_stats,

  # --- CAMO variants ---
  "camo_red":     _get_camo_red_stats,
  "camo_blue":    _get_camo_blue_stats,
  "camo_green":   _get_camo_green_stats,
  "camo_yellow":  _get_camo_yellow_stats,
  "camo_pink":    _get_camo_pink_stats,
  "camo_black":   _get_camo_black_stats,
  "camo_white":   _get_camo_white_stats,
  "camo_lead":    _get_camo_lead_stats,
  "camo_zebra":   _get_camo_zebra_stats,
  "camo_rainbow": _get_camo_rainbow_stats,
  "camo_purple":  _get_camo_purple_stats,
  "camo_ceramic": _get_camo_ceramic_stats,

  # --- MOAB-class CAMO (not present by default—you may want to add these helpers) ---
  "camo_moab":    _get_camo_moab_stats,
  "camo_bfb":     _get_camo_bfb_stats,
  "camo_zomg":    _get_camo_zomg_stats,

  # --- FORTIFIED + CAMO crossover waves (rounds 126–133) ---
  "fortified_camo_lead":     _get_fortified_camo_lead_stats,
  "fortified_camo_ceramic":  _get_fortified_camo_ceramic_stats,
  "fortified_camo_moab":     _get_fortified_camo_moab_stats,
  "fortified_camo_bfb":      _get_fortified_camo_bfb_stats,
  "fortified_camo_zomg":     _get_fortified_camo_zomg_stats,
}

var current_wave_index = 0
var bloons_in_wave: Array[Dictionary] = [] # Holds {"stats_func": Callable, "delay": float}
var current_bloon_spawn_index: int = 0
var bloons_spawned_in_wave = 0
# --- NEW: Tracking active bloons ---
var active_bloons_in_current_round: int = 0
var spawning_complete_for_current_round: bool = false

const BASE_RED_SPEED = 2.0 # Define base speed for multipliers

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
					var fn = STATS_FUNC_MAP.get(key)
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
	var child_stats = _get_camo_regrow_ceramic_stats() # Use dedicated function
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

#region Modifiers

# --- Fortified Stat Functions ---
func _get_fortified_lead_stats() -> BloonStats:
	var stats = _get_lead_stats()
	stats.health = 2 # Fortified Lead has 2 health (vs 1)
	stats.is_fortified = true
	return stats

func _get_fortified_ceramic_stats() -> BloonStats:
	var stats = _get_ceramic_stats()
	stats.health *= 2 # Fortified Ceramic has 20 health (vs 10)
	stats.is_fortified = true
	return stats

func _get_fortified_purple_stats() -> BloonStats:
	var stats = _get_purple_stats()
	# Fortified Purple has 2 health? (Needs confirmation, assuming 1 layer still)
	stats.is_fortified = true
	return stats

func _get_fortified_moab_stats() -> BloonStats:
	var stats = _get_moab_stats()
	stats.health *= 2 # Fortified MOAB has 400 health (vs 200)
	stats.is_fortified = true
	# Children are standard Ceramics
	return stats

func _get_fortified_bfb_stats() -> BloonStats:
	var stats = _get_bfb_stats()
	stats.health *= 2 # Fortified BFB has 1400 health (vs 700)
	stats.is_fortified = true
	# Children are standard MOABs
	return stats

func _get_fortified_zomg_stats() -> BloonStats:
	var stats = _get_zomg_stats()
	stats.health *= 2 # Fortified ZOMG has 8000 health (vs 4000)
	stats.is_fortified = true
	# Children are standard BFBs
	return stats

func _get_fortified_ddt_stats() -> BloonStats:
	var stats = _get_ddt_stats()
	stats.health *= 2 # Fortified DDT has 800 health (vs 400)
	stats.is_fortified = true
	# Children are Camo Regrow Ceramics (already handled by _get_ddt_stats child)
	return stats

func _get_fortified_bad_stats() -> BloonStats:
	var stats = _get_bad_stats()
	stats.health *= 2 # Fortified BAD has 40000 health (vs 20000)
	stats.is_fortified = true
	# Children are standard ZOMGs and DDTs (handled by BAD pop logic)
	return stats

# --- Camo Stat Functions ---
func _get_camo_lead_stats() -> BloonStats:
	var stats = _get_lead_stats()
	stats.is_camo = true
	return stats

func _get_camo_purple_stats() -> BloonStats:
	var stats = _get_purple_stats()
	stats.is_camo = true
	return stats

func _get_camo_ceramic_stats() -> BloonStats:
	var stats = _get_ceramic_stats()
	stats.is_camo = true
	return stats

# --- NEW ---
func _get_camo_red_stats() -> BloonStats: var stats = _get_red_stats(); stats.is_camo = true; return stats
func _get_camo_blue_stats() -> BloonStats: var stats = _get_blue_stats(); stats.is_camo = true; return stats
func _get_camo_green_stats() -> BloonStats: var stats = _get_green_stats(); stats.is_camo = true; return stats
func _get_camo_yellow_stats() -> BloonStats: var stats = _get_yellow_stats(); stats.is_camo = true; return stats
func _get_camo_pink_stats() -> BloonStats: var stats = _get_pink_stats(); stats.is_camo = true; return stats
func _get_camo_black_stats() -> BloonStats: var stats = _get_black_stats(); stats.is_camo = true; return stats
func _get_camo_white_stats() -> BloonStats: var stats = _get_white_stats(); stats.is_camo = true; return stats
func _get_camo_zebra_stats() -> BloonStats: var stats = _get_zebra_stats(); stats.is_camo = true; return stats
func _get_camo_rainbow_stats() -> BloonStats: var stats = _get_rainbow_stats(); stats.is_camo = true; return stats

# --- MOAB-class pure camo helpers ---
func _get_camo_moab_stats() -> BloonStats:
	var s = _get_moab_stats()
	s.is_camo = true
	return s

func _get_camo_bfb_stats() -> BloonStats:
	var s = _get_bfb_stats()
	s.is_camo = true
	return s

func _get_camo_zomg_stats() -> BloonStats:
	var s = _get_zomg_stats()
	s.is_camo = true
	return s

# --- Regrow Stat Functions ---
func _get_regrow_lead_stats() -> BloonStats:
	var stats = _get_lead_stats()
	stats.is_regrow = true
	return stats

# --- NEW ---
func _get_regrow_red_stats() -> BloonStats: var stats = _get_red_stats(); stats.is_regrow = true; return stats
func _get_regrow_blue_stats() -> BloonStats: var stats = _get_blue_stats(); stats.is_regrow = true; return stats
func _get_regrow_green_stats() -> BloonStats: var stats = _get_green_stats(); stats.is_regrow = true; return stats
func _get_regrow_yellow_stats() -> BloonStats: var stats = _get_yellow_stats(); stats.is_regrow = true; return stats
func _get_regrow_pink_stats() -> BloonStats: var stats = _get_pink_stats(); stats.is_regrow = true; return stats
func _get_regrow_black_stats() -> BloonStats: var stats = _get_black_stats(); stats.is_regrow = true; return stats
func _get_regrow_white_stats() -> BloonStats: var stats = _get_white_stats(); stats.is_regrow = true; return stats
func _get_regrow_zebra_stats() -> BloonStats: var stats = _get_zebra_stats(); stats.is_regrow = true; return stats
func _get_regrow_rainbow_stats() -> BloonStats: var stats = _get_rainbow_stats(); stats.is_regrow = true; return stats
func _get_regrow_purple_stats() -> BloonStats: var stats = _get_purple_stats(); stats.is_regrow = true; return stats
func _get_regrow_ceramic_stats() -> BloonStats: var stats = _get_ceramic_stats(); stats.is_regrow = true; return stats


# --- Combined Stat Functions ---
func _get_camo_regrow_lead_stats() -> BloonStats:
	var stats = _get_lead_stats()
	stats.is_camo = true
	stats.is_regrow = true
	return stats

func _get_fortified_camo_lead_stats() -> BloonStats:
	var stats = _get_fortified_lead_stats()
	stats.is_camo = true
	return stats

func _get_fortified_camo_ceramic_stats() -> BloonStats:
	var stats = _get_fortified_ceramic_stats()
	stats.is_camo = true
	return stats

func _get_fortified_camo_regrow_lead_stats() -> BloonStats:
	# Needed for r126
	var stats = _get_fortified_lead_stats()
	stats.is_camo = true
	stats.is_regrow = true
	return stats

func _get_camo_regrow_ceramic_stats() -> BloonStats:
	# Needed for DDT children
	var stats = _get_ceramic_stats()
	stats.is_camo = true
	stats.is_regrow = true
	return stats

# --- NEW ---
func _get_camo_regrow_red_stats() -> BloonStats: var stats = _get_red_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_blue_stats() -> BloonStats: var stats = _get_blue_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_green_stats() -> BloonStats: var stats = _get_green_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_yellow_stats() -> BloonStats: var stats = _get_yellow_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_pink_stats() -> BloonStats: var stats = _get_pink_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_black_stats() -> BloonStats: var stats = _get_black_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_white_stats() -> BloonStats: var stats = _get_white_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_zebra_stats() -> BloonStats: var stats = _get_zebra_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_rainbow_stats() -> BloonStats: var stats = _get_rainbow_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_purple_stats() -> BloonStats: var stats = _get_purple_stats(); stats.is_camo = true; stats.is_regrow = true; return stats

# --- FORTIFIED + CAMO helpers for MOAB-class bloons ---
func _get_fortified_camo_moab_stats() -> BloonStats:
	var s = _get_fortified_moab_stats()
	s.is_camo = true
	return s

func _get_fortified_camo_bfb_stats() -> BloonStats:
	var s = _get_fortified_bfb_stats()
	s.is_camo = true
	return s

func _get_fortified_camo_zomg_stats() -> BloonStats:
	var s = _get_fortified_zomg_stats()
	s.is_camo = true
	return s

#endregion Modifiers
#endregion
