# File: res://projectile/projectile.gd
extends Area3D

# REMOVED: signal returned_to_pool(node: Node)

# @export var stats: ProjectileStats # Stats are now assigned by set_stats or pool_reset
var stats: ProjectileStats # Internal reference

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
	# Mesh is applied when stats are set


# --- NEW: Method to explicitly set stats ---
func set_stats(p_stats: ProjectileStats):
	if not p_stats:
		printerr("Projectile %s received null stats!" % name)
		stats = ProjectileStats.new() # Fallback to default
	else:
		stats = p_stats
	# Apply mesh whenever stats are set or reset
	_apply_mesh_from_stats()
	# Reset internal state based on these stats (like in pool_reset)
	current_pierce = stats.pierce if stats else 1
	if lifetime_timer:
		lifetime_timer.wait_time = stats.lifetime if stats else 1.0


# Called by the Tower's pool logic when reusing the node.
func pool_reset():
	is_released = false
	if not stats:
		# This *shouldn't* happen if set_stats was called during pool init/re-init
		printerr("Projectile %s trying to reset without assigned stats!" % name)
		# Attempt to get default stats? Or just return? Let's try assigning default.
		set_stats(ProjectileStats.new()) # Assign default stats if missing
		# If it still fails, we might have a bigger issue
		if not stats:
			printerr("Projectile %s failed to get default stats on reset!" % name)
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
	# Mesh should be correct from the last set_stats call


# Called by the Tower *after* adding the projectile to the scene tree.
func activate():
	if not stats:
		printerr("Projectile %s activated without stats!" % name)
		release_to_pool()
		return
	lifetime_timer.start()


func _physics_process(delta):
	if not stats or is_released: return # Check stats validity here
	# ... (Movement logic remains the same) ...
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
	if not stats: return # Check stats validity
	# ... (Remains the same) ...
	if not stats.homing_enabled:
		move_direction = initial_direction.normalized()


func set_target(t: Node3D):
	if not stats: return # Check stats validity
	# ... (Remains the same) ...
	if stats and stats.homing_enabled:
		target = t
	else:
		target = null


func _on_area_entered(other_area: Area3D):
	if not stats or is_released: return # Check stats validity
	# ... (Hit detection logic remains mostly the same) ...
	var parent_node = other_area.get_parent()
	if not (parent_node is PathFollow3D and parent_node.is_in_group("bloons") and current_pierce > 0):
		return
	var bloon_stats: BloonStats = null
	if parent_node.has_method("get"): bloon_stats = parent_node.stats
	if not bloon_stats: return
	if bloon_stats.is_lead and not stats.can_pop_lead:
		release_to_pool() # Don't print, just release
		return

	# --- Calculate actual damage dealt ---
	var actual_damage = stats.damage

	# Apply crit damage (if applicable - needs tower to track shot count)
	# This needs a way for the tower to tell the projectile if it's a crit.
	# For now, we'll skip crit application directly in projectile.
	# if stats.crit_frequency > 0 and (shot_counter % stats.crit_frequency == 0): # Needs shot_counter info
	#	actual_damage += stats.crit_extra_damage

	# Apply bonus damage based on bloon type
	if bloon_stats.is_fortified:
		actual_damage += stats.extra_fortified_damage
	if bloon_stats.bloon_type == "Ceramic": # Check specific type
		actual_damage += stats.extra_ceramic_damage
	if bloon_stats.is_lead: # Check lead property
		actual_damage += stats.extra_lead_damage

	# --- Apply Damage ---
	if parent_node.has_method("take_damage"):
		# --- Debug: Log projectile ID before dealing damage ---
		print("Projectile %s (ID: %d) dealing %d damage to %s" % [name, get_instance_id(), actual_damage, parent_node.name])
		parent_node.take_damage(actual_damage, self) # Pass projectile instance

	current_pierce -= 1
	if current_pierce <= 0:
		release_to_pool()


## Call this instead of queue_free()
func release_to_pool():
	if is_released: return
	is_released = true

	set_physics_process(false)
	visible = false
	if lifetime_timer: lifetime_timer.stop() # Ensure timer exists

	# Remove from scene tree
	if get_parent():
		get_parent().remove_child.call_deferred(self) # Use deferred for safety

	# --- Return to owner tower's pool ---
	if owner_tower and owner_tower.has_method("_return_projectile_to_pool"):
		# Use call_deferred to avoid potential issues if called during physics process
		owner_tower._return_projectile_to_pool.call_deferred(self)
	else:
		# Don't print error if owner_tower is null (might happen during scene close)
		if owner_tower:
			printerr("Projectile %s cannot return to pool: Owner tower invalid or missing method." % name)
		# If it can't return, free it to prevent leaks
		queue_free()

	# DO NOT emit signal anymore


# Helper to set mesh based on stats
func _apply_mesh_from_stats():
	if mesh_instance and stats and stats.mesh:
		mesh_instance.mesh = stats.mesh
	elif mesh_instance:
		# Optionally set a default mesh if stats or stats.mesh is null
		# mesh_instance.mesh = preload("res://path/to/default_projectile_mesh.tres")
		pass # Or do nothing, leaving it as is
