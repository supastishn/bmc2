# File: res://bloon/bloon.gd
extends PathFollow3D

## Signal emitted when the bloon is ready to return to the pool.
signal returned_to_pool(node: Node)

@export var stats: BloonStats

var current_health: int
var is_released := false # Flag to prevent double-release

func _ready():
	# Don't initialize health here if it's reset in pool_reset
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
	progress = 0.0 # Reset position on path
	# Parent/Position/Rotation are handled by the WaveManager adding it to Path3D
	visible = true # Ensure it's visible if hidden on release

	# Ensure physics process is enabled
	set_physics_process(true)


func _physics_process(delta):
	if not stats or is_released: return

	progress += stats.speed * delta
	# Must be slightly below 1
	if progress_ratio >= 0.96:
		handle_reached_end()


func take_damage(amount: int):
	if not stats or is_released: return

	current_health -= amount
	if current_health <= 0:
		handle_pop()


func handle_pop():
	if is_released: return
	if stats:
		GameManager.increase_cash(stats.cash_value)
		# TODO: Child Spawning - This will also need to use the pool!
		# if stats.child_bloon_scene and stats.child_bloon_count > 0:
		#     for i in range(stats.child_bloon_count):
		#         var child_bloon = NodePoolManager.request_node(stats.child_bloon_scene)
		#         if child_bloon:
		#             # Need to add it to the *same path* as this bloon
		#             var path = get_parent()
		#             if path is Path3D:
		#                 path.add_child(child_bloon)
		#                 child_bloon.progress = self.progress # Start at same position
		#             else: # Fallback if parent isn't path? Add to root?
		#                 get_tree().root.add_child(child_bloon)
		#                 child_bloon.global_position = self.global_position # Approximate position
	print("Bloon Popped!")
	release_to_pool()


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
	set_physics_process(false)
	visible = false # Optionally hide it immediately

	# Remove from scene BEFORE emitting signal
	if get_parent():
		get_parent().remove_child.call_deferred(self)

	# Signal the pool manager to take it back
	emit_signal("returned_to_pool", self)

	# DO NOT queue_free() here!
