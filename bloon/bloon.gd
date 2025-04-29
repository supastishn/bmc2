# File: res://bloon/bloon.gd
extends PathFollow3D

## Signal emitted when the bloon is ready to return to the pool.
## Passes an array of BloonStats for children to be spawned and the progress ratio.
signal spawn_children_requested(children_stats_array: Array, spawn_progress_ratio: float, popping_projectile: Object) # ADDED projectile
signal returned_to_pool(node: Node) # This signal is used by NodePoolManager
# --- NEW: Signal emitted when the bloon is definitively off the field ---
signal bloon_removed_from_play

@export var stats: BloonStats
@onready var regrow_timer: Timer = $RegrowTimer # Added

var current_health: int
var max_health: int # Added for regrow cap
var is_released := false # Flag to prevent double-release
# How long after being hit before regrow starts
const REGROW_DELAY = 2.0
# How often the bloon regrows one layer
# --- Spawn Immunity ---
const REGROW_INTERVAL = 1.0
var _immune_to_projectiles: Array[Object] = [] # Projectiles to ignore temporarily

func _ready():
	# Don't initialize health here if it's reset in pool_reset
	if not regrow_timer:
		printerr("Bloon %s is missing RegrowTimer node!" % name)
	else:
		regrow_timer.one_shot = false # It should trigger repeatedly if active
		regrow_timer.wait_time = REGROW_INTERVAL
		regrow_timer.timeout.connect(_on_regrow_timer_timeout)
	pass

# Called by NodePoolManager when reusing the node
func pool_reset():
	is_released = false # Reset release flag
	# Stats and health are now set by initialize_with_stats

	progress = 0.0 # Reset position on path
	visible = true # Ensure it's visible if hidden on release

	# Stop regrow timer initially
	if regrow_timer:
		regrow_timer.stop()

	# Ensure physics process is enabled (will be started in _physics_process if needed)

	# Ensure physics process is enabled
	set_physics_process(true)


func _physics_process(delta):
	if not stats or is_released: return

	progress += stats.speed * delta
	# Must be slightly below 1
	if progress_ratio >= 0.99: # Changed threshold to be closer to end
		handle_reached_end()


# --- NEW: Called by WaveManager after getting node from pool ---
func initialize_with_stats(new_stats: BloonStats, immune_to_projectile: Object = null): # ADDED immunity param
	# print_debug("Initializing %s, Immune to: %s" % [new_stats.bloon_type if new_stats else "Unknown", immune_to_projectile]) # Debug
	if not new_stats:
		printerr("Bloon %s received null stats during initialization!" % name)
		release_to_pool() # Release it back if stats are invalid
		return

	stats = new_stats
	current_health = stats.health
	max_health = stats.health # Store the original health
	# --- Debug: Confirm health initialization ---
	# --- Set Temporary Spawn Immunity ---
	_immune_to_projectiles.clear() # Clear any previous immunity
	if immune_to_projectile != null:
		# --- Debug: Log projectile ID being added to immunity ---
		print("Bloon '%s' adding immunity against Projectile ID: %d" % [stats.bloon_type if stats else "Unknown", immune_to_projectile.get_instance_id()])
		_immune_to_projectiles.append(immune_to_projectile)
		_clear_spawn_immunity.call_deferred() # Clear immunity after this frame
		# print_debug("Added immunity for %s against %s" % [stats.bloon_type if stats else "Unknown", immune_to_projectile]) # Debug
	else:
		# --- Debug: Log if no projectile immunity is being added ---
		print("Bloon '%s' initializing with NO projectile immunity." % [stats.bloon_type if stats else "Unknown"])

	print("Initialized Bloon '%s' with health: %d (from stats: %d)" % [stats.bloon_type if stats else "Unknown", current_health, stats.health])
	# TODO: Optionally update mesh/material based on stats here if needed
	# Must be slightly below 1
	if progress_ratio >= 0.99: # Changed threshold to be closer to end
		handle_reached_end()


# --- NEW: Clear Spawn Immunity ---
func _clear_spawn_immunity():
	# print_debug("Clearing spawn immunity list for %s (contained %d)" % [stats.bloon_type if stats else "Unknown", _immune_to_projectiles.size()]) # Debug
	# --- Debug: Log IDs being cleared ---
	var ids_to_clear = []
	for proj in _immune_to_projectiles:
		ids_to_clear.append(proj.get_instance_id() if is_instance_valid(proj) else "Invalid")
	print("Bloon '%s' clearing spawn immunity for Projectile IDs: %s" % [stats.bloon_type if stats else "Unknown", ids_to_clear])
	_immune_to_projectiles.clear()


func take_damage(amount: int, source_projectile: Object = null): # ADDED source_projectile param
	if not stats or is_released: return

	# --- Debug: Log incoming projectile ID and current immunity IDs ---
	var incoming_id = source_projectile.get_instance_id() if is_instance_valid(source_projectile) else "None"
	var immune_ids = []
	for proj in _immune_to_projectiles: immune_ids.append(proj.get_instance_id() if is_instance_valid(proj) else "Invalid")
	# --- Debug: Print incoming projectile and immunity list ---
	print("Take Damage on %s: Incoming projectile ID %s. Immune to IDs: %s" % [stats.bloon_type if stats else "Unknown", incoming_id, immune_ids])

	if not _immune_to_projectiles.is_empty() and source_projectile in _immune_to_projectiles:
		print("Bloon '%s' ignored damage from projectile %s due to spawn immunity." % [stats.bloon_type if stats else "Unknown", source_projectile]) # Debug
		return # Ignore damage from the specific projectile it should be immune to

	# Stop and reset regrow timer if it's a regrow bloon
	if stats.is_regrow and regrow_timer:
		regrow_timer.stop()
		# Start a one-shot timer to *begin* regrowing after a delay
		regrow_timer.wait_time = REGROW_DELAY
		regrow_timer.one_shot = true # Temporarily one-shot for the delay
		regrow_timer.start()

	# Print original health and damage amount
	print("Bloon '%s' health before damage: %d (taking %d damage)" % [stats.bloon_type if stats else "Unknown", current_health, amount])

	current_health -= amount
	# Print new health
	print("Bloon '%s' health after damage: %d" % [stats.bloon_type if stats else "Unknown", current_health])
	if current_health <= 0:		
		handle_pop(source_projectile) # Pass the projectile that caused the pop


func handle_pop(source_projectile_that_popped_me: Object): # ADDED parameter
	if is_released: return # Prevent double processing if pop happens quickly
	if stats:
		GameManager.increase_cash(stats.cash_value)

		# --- Child Spawning ---
		var children_to_spawn: Array = []
		if stats.bloon_type == "Zebra":
			# Special case: 1 Black + 1 White
			children_to_spawn = [WaveManager._get_black_stats(), WaveManager._get_white_stats()]
		elif stats.bloon_type == "BAD":
			# Special case: 2 ZOMG + 3 DDT
			children_to_spawn = [
				WaveManager._get_zomg_stats(), WaveManager._get_zomg_stats(),
				WaveManager._get_ddt_stats(), WaveManager._get_ddt_stats(), WaveManager._get_ddt_stats()
			]
		elif stats.child_bloon_stats and stats.child_bloon_count > 0:
			# Standard case: N children of the same type
			for i in range(stats.child_bloon_count):
				children_to_spawn.append(stats.child_bloon_stats)

		if not children_to_spawn.is_empty():
			emit_signal("spawn_children_requested", children_to_spawn, progress_ratio, source_projectile_that_popped_me)

	print("Bloon Popped!")
	# Stop regrow timer permanently if popped
	if regrow_timer: regrow_timer.stop()
	release_to_pool()


func _on_regrow_timer_timeout():
	if is_released or not stats or not stats.is_regrow: return

	# Check if it was the initial delay timer
	if regrow_timer.one_shot:
		# The delay finished, now start the actual regrow interval
		regrow_timer.wait_time = REGROW_INTERVAL
		regrow_timer.one_shot = false
		regrow_timer.start() # Start the repeating timer
		return # Don't regrow on the first timeout after delay

	# This is a regular regrow tick
	if current_health < max_health:
		current_health += 1
		print("Bloon %s regrew to %d/%d health" % [stats.bloon_type, current_health, max_health])
		# TODO: Update visual representation if needed
	else:
		# Reached max health, stop regrowing until damaged again
		regrow_timer.stop()

func handle_reached_end():
	if is_released: return
	GameManager.decrease_lives(1)
	print("Bloon Reached End!")
	release_to_pool()


## Call this instead of queue_free()
func release_to_pool():
	if is_released: return # Already processed
	is_released = true

	# Stop processing
	# Stop processing
	set_physics_process(false)
	visible = false # Optionally hide it immediately

	# --- NEW: Emit removal signal BEFORE returning to pool ---
	emit_signal("bloon_removed_from_play")

	# Stop regrow timer if active
	if regrow_timer: regrow_timer.stop()

	# Remove from scene BEFORE emitting signal
	if get_parent():
		get_parent().remove_child.call_deferred(self) # Use deferred for safety

	# Signal the pool manager to take it back
	emit_signal("returned_to_pool", self)

	# DO NOT queue_free() here!


# Helper to get stats (used by projectile potentially)
func get_stats() -> BloonStats:
	return stats
