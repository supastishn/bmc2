# File: res://bloon/bloon.gd
extends PathFollow3D

## Assign a BloonStats resource file (.tres) in the Inspector.
@export var stats: BloonStats

# Internal state
var current_health: int

func _ready():
	if not stats:
		printerr("Bloon scene %s is missing its BloonStats resource!" % name)
		# Optionally set default values or handle error
		current_health = 1
		return
	current_health = stats.health


func _physics_process(delta):
	if not stats: return # Don't move if stats are missing

	# Move the bloon along the path
	progress += stats.speed * delta

	# Optional: Keep bloon upright if the path twists weirdly
	# rotation.x = 0
	# rotation.z = 0

	# Check if reached the end (progress_ratio is 0 to 1)
	# Use >= 1.0 for robustness, though 0.95 might work visually
	if progress_ratio >= 1.0:
		handle_reached_end()


func take_damage(amount: int):
	if not stats: return # Cannot take damage if stats are missing

	current_health -= amount
	# Optional: Add visual feedback (flash color, etc.)
	if current_health <= 0:
		handle_pop()


func handle_pop():
	if stats:
		GameManager.increase_cash(stats.cash_value)
		# TODO: Implement child spawning if stats.child_bloon_scene is set
	print("Bloon Popped!")
	queue_free() # Remove the bloon from the scene


func handle_reached_end():
	# TODO: Consider bloon value/type if leaking costs different lives
	GameManager.decrease_lives(1)
	print("Bloon Reached End!")
	queue_free() # Remove the bloon from the scene
