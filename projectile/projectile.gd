# File: res://projectile/projectile.gd
extends Area3D

# REMOVED: signal returned_to_pool(node: Node)

@export var stats: ProjectileStats # Stats are now assigned ONCE by the tower pool init

# Internal state
var current_pierce: int = 1
var target = null
var move_direction: Vector3 = Vector3.FORWARD
var is_released := false

# Reference to the tower that owns this projectile's pool
var owner_tower: Node = null # <<< ADDED

@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D # Assuming this name

func _ready():
	# Timer is stopped/started by pool_reset/activate
	lifetime_timer.stop()
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	# Ensure mesh is set based on initial stats (assigned by tower pool init)
	_apply_mesh_from_stats()


# Called by the Tower's pool logic when reusing the node.
func pool_reset():
	is_released = false
	if not stats:
		# This shouldn't happen if initialized correctly by the tower pool
		printerr("Projectile %s trying to reset without stats!" % name)
		# We can't really recover here easily, maybe force release?
		if owner_tower and owner_tower.has_method("_return_projectile_to_pool"):
			owner_tower._return_projectile_to_pool(self)
		return

	# Reset internal state based on the already assigned stats
	current_pierce = stats.pierce
	target = null
	move_direction = Vector3.FORWARD
	visible = true
	if lifetime_timer:
	# Reset timer duration and ensure it's stopped
		lifetime_timer.wait_time = stats.lifetime
		lifetime_timer.stop()

	# Ensure physics process is enabled
	set_physics_process(true)
	# Mesh should already be correct from initial pool setup


# Called by the Tower *after* adding the projectile to the scene tree.
func activate():
	lifetime_timer.start()


func _physics_process(delta):
	# ... (Movement logic remains the same) ...
	if not stats or is_released: return
	var velocity: Vector3 = Vector3.ZERO
	var can_home = stats.homing_enabled and is_instance_valid(target)
	if can_home:
		var direction_to_target = global_position.direction_to(target.global_position)
		var current_forward = global_transform.basis.z
		var target_forward = direction_to_target.normalized()
		if current_forward.cross(target_forward).length_squared() > 0.001:
			var rotation_angle = current_forward.signed_angle_to(target_forward, global_transform.basis.y)
			var max_angle = stats.homing_turn_rate * delta
			var clamped_angle = clamp(rotation_angle, -max_angle, max_angle)
			rotate_object_local(Vector3.UP, clamped_angle)
		velocity = global_transform.basis.z * stats.speed
	else:
		velocity = move_direction * stats.speed
	global_translate(velocity * delta)
	move_direction = global_transform.basis.z.normalized()


func initialize_direction(initial_direction: Vector3):
	# ... (Remains the same) ...
	if not stats.homing_enabled:
		move_direction = initial_direction.normalized()


func set_target(t: Node3D):
	# ... (Remains the same) ...
	if stats and stats.homing_enabled:
		target = t
	else:
		target = null


func _on_area_entered(other_area: Area3D):
	# ... (Hit detection logic remains mostly the same) ...
	if not stats or is_released: return
	var parent_node = other_area.get_parent()
	if not (parent_node is PathFollow3D and parent_node.is_in_group("bloons") and current_pierce > 0):
		return
	var bloon_stats: BloonStats = null
	if parent_node.has_method("get"): bloon_stats = parent_node.stats
	if not bloon_stats: return
	if bloon_stats.is_lead and not stats.can_pop_lead:
		release_to_pool() # Don't print, just release
		return
	if parent_node.has_method("take_damage"):
		parent_node.take_damage(stats.damage)
	current_pierce -= 1
	if current_pierce <= 0:
		release_to_pool()


## Call this instead of queue_free()
func release_to_pool():
	if is_released: return
	is_released = true

	set_physics_process(false)
	visible = false
	lifetime_timer.stop()

	# Remove from scene tree
	if get_parent():
		get_parent().remove_child.call_deferred(self) # Use deferred for safety

	# --- Return to owner tower's pool ---
	if owner_tower and owner_tower.has_method("_return_projectile_to_pool"):
		# Use call_deferred to avoid potential issues if called during physics process
		owner_tower._return_projectile_to_pool.call_deferred(self)
	else:
		printerr("Projectile %s cannot return to pool: Owner tower invalid or missing method." % name)
		# If it can't return, free it to prevent leaks
		queue_free()

	# DO NOT emit signal anymore


# Helper to set mesh based on stats
func _apply_mesh_from_stats():
	if mesh_instance and stats and stats.mesh:
		mesh_instance.mesh = stats.mesh
