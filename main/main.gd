# File: res://main/main.gd
extends Node3D

# --- Existing Variables ---
@onready var camera: Camera3D = $Camera3D
@onready var wave_manager: Node = $WaveManager
@onready var tower_placement_gui: Control = $Game/TowerPlacementGUI
@onready var towers_node: Node3D = $Towers

# --- Placement State Variables ---
var is_placing_tower: bool = false
# var tower_to_place_scene: PackedScene = null # No longer needed directly here
var tower_to_place_name: String = "" # <<< ADDED
var tower_to_place_cost: int = 0
var tower_preview_instance: Node3D = null
var current_preview_stats: Dictionary = {} # <<< To hold generated stats for preview
var can_place_at_current_pos: bool = false

# Materials for preview feedback
@export var valid_placement_material: Material # Assign in editor
@export var invalid_placement_material: Material # Assign in editor

# Scene for the base tower structure (visuals, placement body, etc.)
@export var base_tower_scene: PackedScene = preload("res://tower/tower.tscn") # <<< ADDED

func _ready():
	# --- Existing Ready Code ---
	# ... (Setup materials, check nodes)

	# Connect GUI signal (expects tower_name now)
	if tower_placement_gui:
		print(tower_placement_gui.tower_selected_for_placement)
		tower_placement_gui.tower_selected_for_placement.connect(_on_tower_selected_for_placement)
	else:
		printerr("TowerPlacementGUI node not found or assigned in Main script!")

	if not base_tower_scene:
		printerr("Base Tower Scene not assigned in Main script!")


func _input(event: InputEvent):
	if not is_placing_tower: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_place_tower()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_placement()
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		_cancel_placement()


func _physics_process(delta):
	# --- Placement Preview Logic ---
	if is_placing_tower and tower_preview_instance:
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1 << (5 - 1)) # Mask for placeable_ground (Layer 5)
		var space_state = get_world_3d().direct_space_state
		var result = space_state.intersect_ray(query)

		if result:
			tower_preview_instance.global_position = result.position
			tower_preview_instance.visible = true
			can_place_at_current_pos = _is_placement_valid(tower_preview_instance)
			_update_preview_material(can_place_at_current_pos)
		else:
			tower_preview_instance.visible = false
			can_place_at_current_pos = false


# <<< MODIFIED: Receives tower_name instead of scene >>>
func _on_tower_selected_for_placement(pname: String, cost: int):
	print('hi')
	if is_placing_tower: _cancel_placement()

	print("Starting placement for: ", pname)

	# --- Get stats from factory (using default 000 path for preview) ---
	current_preview_stats = TowerFactory.create_stats(pname, "000")
	if not current_preview_stats or not current_preview_stats.has("tower"):
		printerr("Failed to get base stats from TowerFactory for preview: ", name)
		return

	is_placing_tower = true
	tower_to_place_name = pname
	tower_to_place_cost = cost

	# Instantiate the BASE tower scene for the preview structure
	tower_preview_instance = base_tower_scene.instantiate()

	# --- Apply mesh from generated stats ---
	var tower_stats: TowerStats = current_preview_stats.tower
	var mesh_instance = tower_preview_instance.get_node_or_null("MeshInstance3D")
	if mesh_instance and tower_stats.mesh:
		mesh_instance.mesh = tower_stats.mesh
	else:
		printerr("Preview instance missing MeshInstance3D or generated stats missing mesh!")

	# Configure preview collision/range (disable range, add overlap check)
	var range_area = tower_preview_instance.get_node_or_null("Area3D")
	if range_area:
		range_area.monitoring = false
		range_area.monitorable = false

	var placement_body = tower_preview_instance.get_node_or_null("PlacementBody")
	if placement_body:
		var overlap_area = Area3D.new()
		overlap_area.name = "PlacementOverlapCheck"
		var placement_shape_node = placement_body.get_node_or_null("CollisionShape3D")
		if placement_shape_node and placement_shape_node.shape:
			var overlap_shape = CollisionShape3D.new()
			overlap_shape.shape = placement_shape_node.shape.duplicate(true) # Deep duplicate shape
			overlap_area.add_child(overlap_shape)
			# Check against placed towers (Layer 6) and track (Layer 7)
			overlap_area.collision_mask = (1 << (6 - 1)) | (1 << (7 - 1))
			tower_preview_instance.add_child(overlap_area)
		else:
			printerr("Preview tower missing PlacementBody/CollisionShape3D or shape!")
	else:
		printerr("Preview tower instance missing PlacementBody!")


	tower_preview_instance.visible = false
	add_child(tower_preview_instance)


func _is_placement_valid(preview_node: Node3D) -> bool:
	var overlap_area = preview_node.get_node_or_null("PlacementOverlapCheck")
	if not overlap_area: return false
	return overlap_area.get_overlapping_areas().is_empty()


func _update_preview_material(is_valid: bool):
	if not tower_preview_instance: return
	var mesh_instance = tower_preview_instance.get_node_or_null("MeshInstance3D")
	if mesh_instance:
		mesh_instance.material_override = valid_placement_material if is_valid else invalid_placement_material

# File: res://main/main.gd
# ... (other code remains the same) ...

func _try_place_tower():
	if not is_placing_tower or not tower_preview_instance or not tower_preview_instance.visible: return

	if can_place_at_current_pos:
		if GameManager.spend_cash(tower_to_place_cost):
			print("Placing tower '%s' at: " % tower_to_place_name, tower_preview_instance.global_position)

			var final_tower = base_tower_scene.instantiate()
			var upgrade_path = "000" # Placeholder for upgrades
			var final_stats_dict = TowerFactory.create_stats(tower_to_place_name, upgrade_path)

			if not final_stats_dict or not final_stats_dict.has("tower") or not final_stats_dict.has("projectile"): # Check both
				printerr("Failed to get FINAL stats from TowerFactory for: ", tower_to_place_name)
				if is_instance_valid(final_tower): final_tower.queue_free()
				_cancel_placement()
				return

			# --- Assign BOTH stats resources to the final tower instance ---
			final_tower.stats = final_stats_dict.tower
			final_tower.projectile_stats = final_stats_dict.projectile # <<< ENSURE THIS IS ASSIGNED

			# Mesh is now applied in tower's _configure_tower (called via deferred in _ready)
			# var final_mesh_instance = final_tower.get_node_or_null("MeshInstance3D")
			# if final_mesh_instance and final_tower.stats.mesh:
			# 	final_mesh_instance.mesh = final_tower.stats.mesh

			towers_node.add_child(final_tower)
			final_tower.global_position = tower_preview_instance.global_position

			_cleanup_placement()
			if tower_placement_gui: tower_placement_gui.reset_status()
		else:
			print("Placement failed: Could not spend cash.")
			if tower_placement_gui: tower_placement_gui.set_status("Error: Insufficient funds!", true)
			_cancel_placement()
	else:
		print("Cannot place tower here (invalid location).")

# ... (rest of main.gd) ...

func _cancel_placement():
	print("Cancelling placement.")
	_cleanup_placement()
	if tower_placement_gui: tower_placement_gui.reset_status()


func _cleanup_placement():
	if is_instance_valid(tower_preview_instance):
		tower_preview_instance.queue_free()
	tower_preview_instance = null
	is_placing_tower = false
	tower_to_place_name = ""
	tower_to_place_cost = 0
	can_place_at_current_pos = false
	current_preview_stats = {}
