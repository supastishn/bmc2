# File: res://autoloads/pool_manager.gd (or node_pool_manager.gd)
# --- AUTOLOAD SCRIPT (Name it NodePoolManager in Project Settings) ---
extends Node

# Dictionary to hold pools. Key: PackedScene, Value: Array of inactive nodes
var _pools := {}

func _ready():
	# Pre-warm pools on game start - ONLY FOR BLOONS NOW
	var bloon_scene = preload("res://bloon/bloon.tscn") # Assuming one type for now
	prepare_pool(bloon_scene, 100) # Pool size for bloons


## Creates a pool for a given scene with an initial size.
func prepare_pool(scene: PackedScene, initial_size: int):
	if not scene:
		printerr("NodePoolManager: Cannot prepare pool for null scene.")
		return
	if _pools.has(scene):
		print("NodePoolManager: Pool for %s already exists." % scene.resource_path)
		return

	_pools[scene] = []
	for i in range(initial_size):
		var node_instance = scene.instantiate()
		# IMPORTANT: Do NOT add to scene tree here.
		# Store the source scene on the node itself for easy return
		node_instance.set_meta("source_scene", scene) # Keep meta for potential future use if needed

		# Connect the node's signal to our return function (Bloon still uses this)
		if node_instance.has_signal("returned_to_pool"):
			# Bind the scene and connect (we no longer invoke call_deferred here)
			node_instance.returned_to_pool.connect(_on_node_returned.bind(scene))
		else:
			# Projectiles won't have this signal anymore, Bloons should
			if not scene.resource_path.contains("projectile"): # Avoid error for projectiles
				printerr("NodePoolManager: Pooled node scene %s is missing 'returned_to_pool' signal!" % scene.resource_path)

		_pools[scene].append(node_instance) # Add to the inactive pool

	print("NodePoolManager: Prepared pool for %s with %d instances." % [scene.resource_path, initial_size])


## Requests an inactive node from the pool or creates a new one if pool is empty.
func request_node(scene: PackedScene) -> Node:
	if not scene:
		printerr("NodePoolManager: Cannot request node for null scene.")
		return null

	# Check if pool exists and has nodes
	if not _pools.has(scene) or _pools[scene].is_empty():
		printerr("NodePoolManager: Pool for %s empty or not prepared. Instantiating fallback." % scene.resource_path)
		var new_node = scene.instantiate()
		# Connect signal for fallback instances too (relevant for Bloons)
		if new_node.has_signal("returned_to_pool"):
			new_node.returned_to_pool.connect(_on_node_returned.bind(scene))
		# Set meta for fallback nodes so they *can* be returned if a pool is created later
		new_node.set_meta("source_scene", scene)
		return new_node

	# Pool has available nodes
	var pooled_node = _pools[scene].pop_back()

	# Call reset method if it exists on the node (relevant for Bloons)
	if pooled_node.has_method("pool_reset"):
		pooled_node.pool_reset()

	return pooled_node


## Called via signal when a node (like a Bloon) is finished.
## The 'bound_scene' argument is passed via the .bind() method during connection.
func _on_node_returned(node: Node, bound_scene: PackedScene):
	if not is_instance_valid(node):
		printerr("NodePoolManager: Attempted to return an invalid node.")
		return

	# Double check the scene matches the pool key, though binding should ensure this
	if not bound_scene or not _pools.has(bound_scene):
		# Fallback check using meta if binding failed or wasn't used
		var source_scene = node.get_meta("source_scene", null) if node.has_meta("source_scene") else null
		if not source_scene or not _pools.has(source_scene):
			printerr("NodePoolManager: Cannot return node - Unknown source scene or pool doesn't exist for: ", node.name)
			node.queue_free() # Prevent leaks if we can't pool it
			return
		else:
			# If meta worked, use that scene key
			bound_scene = source_scene

	# Add the node back to the corresponding pool's inactive list
	_pools[bound_scene].append(node)
	# print("NodePoolManager: Returned node %s to pool %s. Pool size: %d" % [node.name, bound_scene.resource_path, _pools[bound_scene].size()]) # Debug
