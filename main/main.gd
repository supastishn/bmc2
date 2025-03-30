# File: res://main/main.gd
extends Node3D

# --- Existing Variables ---
@onready var camera: Camera3D = $Camera3D
@onready var wave_manager: Node = $WaveManager
@onready var tower_placement_gui: Control = $Game/TowerPlacementGUI
@onready var towers_node: Node3D = $Towers
# --- NEW: Upgrade GUI Reference ---
@onready var tower_upgrade_gui: Control = $Game/TowerUpgradeGUI # Adjust path if needed

# --- Placement State Variables ---
var is_placing_tower: bool = false
var tower_to_place_name: String = ""
var tower_to_place_cost: int = 0
var tower_preview_instance: Node3D = null
var current_preview_stats: Dictionary = {}
var can_place_at_current_pos: bool = false

# Materials for preview feedback
@export var valid_placement_material: Material # Assign in editor
@export var invalid_placement_material: Material # Assign in editor

# Scene for the base tower structure
@export var base_tower_scene: PackedScene = preload("res://tower/tower.tscn")

# --- NEW: Selection State ---
var currently_selected_tower: Node3D = null

# --- Collision Masks ---
const PLACEABLE_GROUND_MASK = 1 << (5 - 1) # Layer 5
const PLACED_TOWER_MASK = 1 << (6 - 1)     # Layer 6 (Make sure towers are on this layer)
const TOWER_PLACEMENT_BLOCKERS_MASK = (1 << (6 - 1)) | (1 << (7 - 1)) # Layer 6 (Towers) & 7 (Track)

func _ready():
	# --- Existing Ready Code ---
	if tower_placement_gui:
		if not tower_placement_gui.tower_selected_for_placement.is_connected(_on_tower_selected_for_placement):
			tower_placement_gui.tower_selected_for_placement.connect(_on_tower_selected_for_placement)
	else:
		printerr("TowerPlacementGUI node not found or assigned in Main script!")

	if not base_tower_scene:
		printerr("Base Tower Scene not assigned in Main script!")

	# --- NEW: Connect Upgrade GUI Signals ---
	if tower_upgrade_gui:
		if not tower_upgrade_gui.upgrade_requested.is_connected(_on_upgrade_requested):
			tower_upgrade_gui.upgrade_requested.connect(_on_upgrade_requested)
		if not tower_upgrade_gui.sell_requested.is_connected(_on_sell_requested):
			tower_upgrade_gui.sell_requested.connect(_on_sell_requested)
		tower_upgrade_gui.hide() # Start hidden
	else:
		printerr("TowerUpgradeGUI node not found or assigned in Main script!")


func _input(event: InputEvent):
	# --- Placement Input ---
	if is_placing_tower:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_try_place_tower()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_cancel_placement()
		elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
			_cancel_placement()
		return # Don't process selection clicks while placing

	# --- Tower Selection Input ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if the click was on the UI first (Upgrade GUI has Stop mouse filter)
		# If the event reaches here, it wasn't on the upgrade GUI.
		_handle_world_click(get_viewport().get_mouse_position())


func _handle_world_click(mouse_pos: Vector2):
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000
	# Raycast specifically for towers (Layer 6)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, PLACED_TOWER_MASK)
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		if collider is StaticBody3D and collider.get_parent() is Node3D:
			var clicked_tower = collider.get_parent()
			# Check if it's actually one of our towers (optional, good practice)
			if clicked_tower.is_in_group("towers") or clicked_tower.has_method("apply_upgrade"): # Check group or method
				select_tower(clicked_tower)
			else:
				deselect_tower() # Clicked something else with the right layer? Deselect.
		else:
			deselect_tower() # Clicked something unexpected
	else:
		deselect_tower() # Clicked empty space or ground


func select_tower(tower: Node3D):
	if tower == currently_selected_tower:
		return # Already selected

	deselect_tower() # Deselect previous one first
	currently_selected_tower = tower
	if tower_upgrade_gui:
		tower_upgrade_gui.display_tower(currently_selected_tower)
	# Optional: Add visual indication for selected tower (e.g., outline, highlight)
	print("Selected Tower: ", currently_selected_tower.name)


func deselect_tower():
	if currently_selected_tower:
		# Optional: Remove visual indication from previously selected tower
		print("Deselected Tower: ", currently_selected_tower.name)
	currently_selected_tower = null
	if tower_upgrade_gui:
		tower_upgrade_gui.hide_panel()


func _physics_process(delta):
	# --- Placement Preview Logic ---
	if is_placing_tower and tower_preview_instance:
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000
		# Use ground mask for placement preview
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, PLACEABLE_GROUND_MASK)
		var space_state = get_world_3d().direct_space_state
		var result = space_state.intersect_ray(query)

		if result:
			tower_preview_instance.global_position = result.position
			tower_preview_instance.visible = true
			# Use blocker mask for placement validation
			can_place_at_current_pos = _is_placement_valid(tower_preview_instance)
			_update_preview_material(can_place_at_current_pos)
		else:
			tower_preview_instance.visible = false
			can_place_at_current_pos = false


func _on_tower_selected_for_placement(pname: String, cost: int):
	if is_placing_tower: _cancel_placement()
	deselect_tower() # Deselect any tower when starting placement

	print("Starting placement for: ", pname)
	current_preview_stats = TowerFactory.create_stats(pname, "000")
	if not current_preview_stats or not current_preview_stats.has("tower"):
		printerr("Failed to get base stats from TowerFactory for preview: ", pname)
		return

	is_placing_tower = true
	tower_to_place_name = pname
	tower_to_place_cost = cost

	tower_preview_instance = base_tower_scene.instantiate()

	var tower_stats: TowerStats = current_preview_stats.tower
	var mesh_instance = tower_preview_instance.get_node_or_null("MeshInstance3D")
	if mesh_instance and tower_stats.mesh:
		mesh_instance.mesh = tower_stats.mesh
	else:
		printerr("Preview instance missing MeshInstance3D or generated stats missing mesh!")

	# Configure preview collision/range
	var range_area = tower_preview_instance.get_node_or_null("Area3D")
	if range_area: range_area.monitoring = false; range_area.monitorable = false

	var placement_body = tower_preview_instance.get_node_or_null("PlacementBody")
	if placement_body:
		var overlap_area = Area3D.new()
		overlap_area.name = "PlacementOverlapCheck"
		var placement_shape_node = placement_body.get_node_or_null("CollisionShape3D")
		if placement_shape_node and placement_shape_node.shape:
			var overlap_shape = CollisionShape3D.new()
			overlap_shape.shape = placement_shape_node.shape.duplicate(true)
			overlap_area.add_child(overlap_shape)
			# Check against blockers mask
			overlap_area.collision_mask = TOWER_PLACEMENT_BLOCKERS_MASK
			tower_preview_instance.add_child(overlap_area)
		else: printerr("Preview tower missing PlacementBody/CollisionShape3D or shape!")
	else: printerr("Preview tower instance missing PlacementBody!")

	tower_preview_instance.visible = false
	add_child(tower_preview_instance)


func _is_placement_valid(preview_node: Node3D) -> bool:
	var overlap_area = preview_node.get_node_or_null("PlacementOverlapCheck")
	if not overlap_area: return false
	# Check both overlapping bodies (other towers) and areas (track)
	return overlap_area.get_overlapping_bodies().is_empty() and overlap_area.get_overlapping_areas().is_empty()


func _update_preview_material(is_valid: bool):
	if not tower_preview_instance: return
	var mesh_instance = tower_preview_instance.get_node_or_null("MeshInstance3D")
	if mesh_instance:
		mesh_instance.material_override = valid_placement_material if is_valid else invalid_placement_material


func _try_place_tower():
	if not is_placing_tower or not tower_preview_instance or not tower_preview_instance.visible: return

	if can_place_at_current_pos:
		if GameManager.spend_cash(tower_to_place_cost):
			print("Placing tower '%s' at: " % tower_to_place_name, tower_preview_instance.global_position)

			var final_tower = base_tower_scene.instantiate()
			var upgrade_path = "000"
			var final_stats_dict = TowerFactory.create_stats(tower_to_place_name, upgrade_path)

			if not final_stats_dict or not final_stats_dict.has("tower") or not final_stats_dict.has("projectile"):
				printerr("Failed to get FINAL stats from TowerFactory for: ", tower_to_place_name)
				if is_instance_valid(final_tower): final_tower.queue_free()
				GameManager.increase_cash(tower_to_place_cost) # Refund
				_cancel_placement()
				return

			final_tower.stats = final_stats_dict.tower
			final_tower.projectile_stats = final_stats_dict.projectile

			# --- Set Initial State (Name, Cost) ---
			final_tower.set_initial_state(tower_to_place_name, tower_to_place_cost)
			final_tower.add_to_group("towers") # Add to group for easier identification

			towers_node.add_child(final_tower)
			final_tower.global_position = tower_preview_instance.global_position

			_cleanup_placement()
			if tower_placement_gui: tower_placement_gui.reset_status()
		else:
			print("Placement failed: Could not spend cash.")
			if tower_placement_gui: tower_placement_gui.set_status("Error: Insufficient funds!", true)
			# Don't cancel placement on insufficient funds, let user try again or cancel
	else:
		print("Cannot place tower here (invalid location).")


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

# --- NEW: Upgrade/Sell Handlers ---

func _on_upgrade_requested(path_index: int, tier: int):
	if not is_instance_valid(currently_selected_tower):
		printerr("Upgrade requested but no tower selected.")
		return

	var tower_name = currently_selected_tower.tower_name
	var upgrade_details = TowerFactory.get_upgrade_details(tower_name, path_index, tier)

	if upgrade_details.is_empty():
		printerr("Upgrade details not found for %s path %d tier %d" % [tower_name, path_index, tier])
		return

	var cost = upgrade_details.cost
	if GameManager.can_afford(cost):
		if GameManager.spend_cash(cost):
			# Attempt to apply the upgrade on the tower node
			if currently_selected_tower.apply_upgrade(path_index, tier, cost):
				print("Upgrade successful!")
				# Refresh the GUI to show new state (updated name, buttons)
				if tower_upgrade_gui:
					tower_upgrade_gui.display_tower(currently_selected_tower)
			else:
				# Upgrade failed validation within the tower itself, refund cash
				print("Upgrade failed validation on tower.")
				GameManager.increase_cash(cost)
		else:
			# This should ideally not happen if can_afford passed, but handle anyway
			print("Upgrade failed: Could not spend cash (race condition?).")
	else:
		print("Upgrade failed: Cannot afford.")
		# Optional: Provide feedback to the player (e.g., flash cost red)


func _on_sell_requested():
	if not is_instance_valid(currently_selected_tower):
		printerr("Sell requested but no tower selected.")
		return

	var sell_value = int(currently_selected_tower.total_spent * 0.7) # Get sell value (70%)
	GameManager.increase_cash(sell_value)
	print("Sold tower %s for %d" % [currently_selected_tower.name, sell_value])

	var tower_to_remove = currently_selected_tower
	deselect_tower() # This also hides the GUI
	tower_to_remove.queue_free()
