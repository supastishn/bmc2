# File: res://projectile/projectile.gd
extends Area3D

## Assign a ProjectileStats resource file (.tres) in the Inspector.
@export var stats: ProjectileStats

# Internal state
var current_pierce: int = 1
var target = null
var move_direction: Vector3 = Vector3.FORWARD

func _ready():
	if not stats:
		printerr("Projectile scene %s is missing its ProjectileStats resource!" % name)
		queue_free()
		return

	current_pierce = stats.pierce

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	var timer = Timer.new()
	timer.name = "LifetimeTimer"
	timer.wait_time = stats.lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()


func _physics_process(delta):
	if not stats: return

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
	if not stats.homing_enabled:
		move_direction = initial_direction.normalized()


func set_target(t: Node3D):
	if stats and stats.homing_enabled:
		target = t
	else:
		target = null


func _on_area_entered(other_area: Area3D):
	if not stats: return

	var parent_node = other_area.get_parent()

	# Ensure we hit a valid bloon node and still have pierce
	if not (parent_node is PathFollow3D and parent_node.is_in_group("bloons") and current_pierce > 0):
		return

	# --- Lead Check ---
	var bloon_stats: BloonStats = parent_node.stats # Get the bloon's stats resource
	if not bloon_stats:
		printerr("Hit bloon %s has no stats!" % parent_node.name)
		return # Cannot determine if lead

	if bloon_stats.is_lead and not stats.can_pop_lead:
		print("Projectile cannot pop Lead bloon: ", parent_node.name)
		# Optionally add a visual effect for ineffective hit (e.g., bounce off)
		queue_free() # Destroy projectile without damaging or reducing pierce
		return
	# --- End Lead Check ---

	print("Projectile hit bloon area: ", parent_node.name)
	if parent_node.has_method("take_damage"):
		parent_node.take_damage(stats.damage)

	# Decrease pierce only after a successful hit on a damageable bloon
	current_pierce -= 1
	if current_pierce <= 0:
		queue_free() # Destroy projectile after pierce is used up
