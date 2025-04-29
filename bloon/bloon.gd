# File: res://bloon/bloon.gd
extends PathFollow3D

## Signal emitted when the bloon is ready to return to the pool.
## Passes an array of BloonStats for children to be spawned and the progress ratio.
signal spawn_children_requested(children_stats_array: Array, spawn_progress_ratio: float)
signal returned_to_pool(node: Node)

@export var stats: BloonStats
@onready var regrow_timer: Timer = $RegrowTimer # Added

var current_health: int
var max_health: int # Added for regrow cap
var is_released := false # Flag to prevent double-release
# How long after being hit before regrow starts
const REGROW_DELAY = 2.0
# How often the bloon regrows one layer
const REGROW_INTERVAL = 1.0

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
	if not stats:
		printerr("Bloon %s trying to reset without stats!" % name)
		# release_to_pool() # Or maybe this?
		return

	# Reset internal state
	current_health = stats.health
	max_health = stats.health # Store the original health
	progress = 0.0 # Reset position on path
	# Parent/Position/Rotation are handled by the WaveManager adding it to Path3D
	visible = true # Ensure it's visible if hidden on release

	# Stop regrow timer initially
	if regrow_timer:
		regrow_timer.stop()

	# Ensure physics process is enabled

	# Ensure physics process is enabled
	set_physics_process(true)


func _physics_process(delta):
	if not stats or is_released: return

	progress += stats.speed * delta
	# Must be slightly below 1
	if progress_ratio >= 0.99: # Changed threshold to be closer to end
		handle_reached_end()


func take_damage(amount: int):
	if not stats or is_released: return

	# Stop and reset regrow timer if it's a regrow bloon
	if stats.is_regrow and regrow_timer:
		regrow_timer.stop()
		# Start a one-shot timer to *begin* regrowing after a delay
		regrow_timer.wait_time = REGROW_DELAY
		regrow_timer.one_shot = true # Temporarily one-shot for the delay
		regrow_timer.start()


	current_health -= amount
	if current_health <= 0:
		handle_pop()


func handle_pop():
	if is_released: return
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
			emit_signal("spawn_children_requested", children_to_spawn, progress_ratio)

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
