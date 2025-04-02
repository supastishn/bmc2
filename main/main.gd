# File: res://main/main.gd
extends Node3D

# --- GUI References ---
@onready var tower_placement_gui: Control = $Game/TowerPlacementGUI
@onready var tower_upgrade_gui: Control = $Game/TowerUpgradeGUI
# --- NEW: References to the actual panels for click blocking ---
@onready var tower_placement_panel: PanelContainer = $Game/TowerPlacementGUI/PanelContainer
@onready var tower_upgrade_panel: PanelContainer = $Game/TowerUpgradeGUI/PanelContainer

# --- Other Scene References ---
@onready var camera: Camera3D = $Camera3D
@onready var wave_manager: Node = $WaveManager
@onready var towers_node: Node3D = $Towers

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

# --- Selection State ---
var currently_selected_tower: Node3D = null

# --- Collision Masks ---
const PLACEABLE_GROUND_LAYER: int = 5 # Ground is on layer 5 (Check ground.tscn -> StaticBody3D layer 16 -> bit 5)
const PLACED_TOWER_LAYER: int = 6     # Towers' clickable body is on layer 6 (Check tower.tscn -> PlacementBody layer 32 -> bit 6)
const TRACK_AREA_LAYER: int = 7       # Track area is on layer 7 (Check Level.tscn -> TrackArea layer 64 -> bit 7)

# --- Calculated Masks ---
# Mask for raycasting onto the ground for placement position
const PLACEABLE_GROUND_MASK = 1 << (PLACEABLE_GROUND_LAYER - 1)
# Mask for raycasting to select placed towers
const PLACED_TOWER_MASK = 1 << (PLACED_TOWER_LAYER - 1)
# Mask for the preview's overlap check (cannot overlap placed towers or track)
const TOWER_PLACEMENT_BLOCKERS_MASK = (1 << (PLACED_TOWER_LAYER - 1)) | (1 << (TRACK_AREA_LAYER - 1))
# --- NEW: Mask for world clicks (Towers, Ground, Track) ---
const WORLD_CLICK_MASK = PLACED_TOWER_MASK | PLACEABLE_GROUND_MASK | (1 << (TRACK_AREA_LAYER - 1))


func _ready():
	# --- Connect Tower Placement GUI Signal ---
	if tower_placement_gui:
		if not tower_placement_gui.tower_selected_for_placement.is_connected(_on_tower_selected_for_placement):
			var err = tower_placement_gui.tower_selected_for_placement.connect(_on_tower_selected_for_placement)
			if err != OK:
				printerr("Failed to connect tower_selected_for_placement signal. Error: ", err)
	else:
		printerr("TowerPlacementGUI node not found or assigned in Main script! Path used: $Game/TowerPlacementGUI")

	# --- Base Tower Scene Check ---
	if not base_tower_scene:
		printerr("Base Tower Scene not assigned in Main script!")

	# --- Connect Upgrade GUI Signals ---
	if tower_upgrade_gui:
		# Connect signals if they exist and aren't already connected
		if tower_upgrade_gui.has_signal("upgrade_requested") and not tower_upgrade_gui.upgrade_requested.is_connected(_on_upgrade_requested):
			tower_upgrade_gui.upgrade_requested.connect(_on_upgrade_requested)
		if tower_upgrade_gui.has_signal("sell_requested") and not tower_upgrade_gui.sell_requested.is_connected(_on_sell_requested):
			tower_upgrade_gui.sell_requested.connect(_on_sell_requested)
		tower_upgrade_gui.hide() # Start hidden
	else:
		printerr("TowerUpgradeGUI node not found or assigned in Main script!")

	# --- Check UI Panel References ---
	if not tower_placement_panel:
		printerr("TowerPlacementGUI PanelContainer node not found! Path: $Game/TowerPlacementGUI/PanelContainer")
	if not tower_upgrade_panel:
		printerr("TowerUpgradeGUI PanelContainer node not found! Path: $Game/TowerUpgradeGUI/PanelContainer")


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
		var mouse_pos = get_viewport().get_mouse_position()

		# --- NEW: Check if click was on blocking UI elements ---
		# Check Tower Placement GUI Panel (assuming it's always visible but might block clicks)
		# Note: Ensure its Mouse Filter is set to Stop in the editor
		if tower_placement_panel and tower_placement_panel.get_global_rect().has_point(mouse_pos):
			# print_debug("Clicked on Tower Placement GUI Panel - Ignoring world click")
			return # Don't process world click if UI was clicked

		# Check Tower Upgrade GUI Panel (only if visible)
		# Note: Ensure its Mouse Filter is set to Stop in the editor
		if tower_upgrade_panel and tower_upgrade_panel.visible and tower_upgrade_panel.get_global_rect().has_point(mouse_pos):
			# print_debug("Clicked on Tower Upgrade GUI Panel - Ignoring world click")
			return # Don't process world click if UI was clicked

		# If click wasn't on blocking UI, handle world click
		_handle_world_click(mouse_pos)


func _handle_world_click(mouse_pos: Vector2):
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000 # Ray length

	# --- MODIFIED: Raycast for Towers, Ground, and Track using WORLD_CLICK_MASK ---
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, WORLD_CLICK_MASK)
	# --- MODIFIED: Need to collide with areas to detect the TrackArea ---
	query.collide_with_areas = true
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)

	if result:
		# print("World Click Raycast Hit: ", result) # Debug: See what was hit
		var collider = result.collider

		# --- Check 1: Was a Tower clicked? ---
		# Assumes the clickable body is named "PlacementBody", is a StaticBody3D, and is on Layer 6
		if collider is StaticBody3D and collider.collision_layer == PLACED_TOWER_MASK and collider.name == "PlacementBody":
			var clicked_tower = collider.get_parent()
			# Verify it's one of our placed towers using the group
			if clicked_tower is Node3D and clicked_tower.is_in_group("towers"):
				select_tower(clicked_tower) # Select the new tower (deselects old one)
				return # Handled

		# --- Check 2: Was the Ground clicked? ---
		# Assumes ground's StaticBody3D is on Layer 5
		elif collider is StaticBody3D and collider.collision_layer == PLACEABLE_GROUND_MASK:
			# print_debug("Clicked on Ground - Deselecting") # Debug
			deselect_tower()
			return # Handled

		# --- Check 3: Was the Track clicked? ---
		# Assumes TrackArea is an Area3D on Layer 7
		elif collider is Area3D and collider.collision_layer == (1 << (TRACK_AREA_LAYER - 1)):
			# print_debug("Clicked on Track - Deselecting") # Debug
			deselect_tower()
			return # Handled

		# --- Else: Clicked something else on the mask layers? ---
		# This case should ideally not happen with correct setup, but if it does, do nothing.
		# print_debug("Clicked on unexpected collider on world mask layers: ", collider) # Debug

	# --- Else: Raycast hit nothing (empty space) ---
	# Do nothing - clicking empty space no longer deselects.
	# print_debug("Clicked on empty space - Doing nothing") # Debug
	pass


func select_tower(tower: Node3D):
	if tower == currently_selected_tower:
		return # Clicked the same tower again

	deselect_tower() # Deselect previous one first
	currently_selected_tower = tower
	print("Selected Tower: ", currently_selected_tower.name)

	# --- Show Upgrade GUI ---
	if tower_upgrade_gui and currently_selected_tower.has_method("get_upgrade_level"): # Check for a method tower has
		tower_upgrade_gui.display_tower(currently_selected_tower)
	else:
		printerr("Cannot display upgrade GUI - GUI node missing or tower missing required methods.")
		# Hide GUI if it failed to display for the new tower
		if tower_upgrade_gui: tower_upgrade_gui.hide_panel()


func deselect_tower():
	if currently_selected_tower:
		print("Deselected Tower: ", currently_selected_tower.name)
		currently_selected_tower = null
		# --- Hide Upgrade GUI ---
		if tower_upgrade_gui:
			tower_upgrade_gui.hide_panel()


func _physics_process(delta):
	# --- Placement Preview Logic ---
	if is_placing_tower and tower_preview_instance:
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000

		# Raycast onto the ground (Layer 5) to position the preview
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, PLACEABLE_GROUND_MASK)
		var space_state = get_world_3d().direct_space_state
		var result = space_state.intersect_ray(query)

		if result:
			tower_preview_instance.global_position = result.position
			tower_preview_instance.visible = true
			# Check if placement is valid at this position using the overlap area
			can_place_at_current_pos = _is_placement_valid(tower_preview_instance)
			_update_preview_material(can_place_at_current_pos)
		else:
			# Mouse is not over the ground layer
			tower_preview_instance.visible = false
			can_place_at_current_pos = false


func _on_tower_selected_for_placement(pname: String, cost: int):
	# If already placing, cancel the previous placement first
	if is_placing_tower:
		_cancel_placement()
	# Deselect any currently selected tower
	deselect_tower()

	print("Starting placement for: ", pname)
	# Get base stats for the preview
	current_preview_stats = TowerFactory.create_stats(pname, "000")
	if not current_preview_stats or not current_preview_stats.has("tower"):
		printerr("Failed to get base stats from TowerFactory for preview: ", pname)
		if tower_placement_gui: tower_placement_gui.set_status("Error: Tower data missing!", true)
		return

	# Check affordability *before* creating preview (optional, but good)
	if not GameManager.can_afford(cost):
		printerr("Cannot start placement: Not enough cash for ", pname)
		if tower_placement_gui: tower_placement_gui.set_status("Error: Insufficient funds!", true)
		return

	# --- Start Placement State ---
	is_placing_tower = true
	tower_to_place_name = pname
	tower_to_place_cost = cost # Store the cost passed from the GUI

	# --- Create Preview Instance ---
	if not base_tower_scene:
		printerr("Cannot create preview: Base Tower Scene not set!")
		_cancel_placement() # Clean up state
		return
	tower_preview_instance = base_tower_scene.instantiate()

	# Apply mesh from generated stats
	var tower_stats: TowerStats = current_preview_stats.tower
	var mesh_instance = tower_preview_instance.get_node_or_null("MeshInstance3D")
	if mesh_instance and tower_stats.mesh:
		mesh_instance.mesh = tower_stats.mesh
	else:
		printerr("Preview instance missing MeshInstance3D or generated stats missing mesh!")
		# Don't necessarily cancel here, might still work without mesh

	# --- Configure Preview Collision ---
	# Disable range detection on preview
	var range_area = tower_preview_instance.get_node_or_null("Area3D")
	if range_area:
		range_area.monitoring = false
		range_area.monitorable = false
		range_area.collision_layer = 0
		range_area.collision_mask = 0

	# Disable the main clickable body (PlacementBody) on the preview
	var placement_body = tower_preview_instance.get_node_or_null("PlacementBody")
	if placement_body:
		placement_body.collision_layer = 0 # Make it not exist on any layer
		placement_body.collision_mask = 0
	else:
		printerr("Preview tower instance missing PlacementBody!")

	# --- Setup Overlap Check Area ---
	var overlap_area = Area3D.new()
	overlap_area.name = "PlacementOverlapCheck"
	var placement_shape_node = placement_body.get_node_or_null("CollisionShape3D") if placement_body else null
	if placement_shape_node and placement_shape_node.shape:
		var overlap_shape = CollisionShape3D.new()
		overlap_shape.shape = placement_shape_node.shape.duplicate(true)
		overlap_area.add_child(overlap_shape)
		overlap_area.collision_mask = TOWER_PLACEMENT_BLOCKERS_MASK
		overlap_area.collision_layer = 0
		overlap_area.monitorable = false
		overlap_area.monitoring = true
		tower_preview_instance.add_child(overlap_area)
	else:
		printerr("Preview tower missing PlacementBody/CollisionShape3D or shape! Cannot create overlap check area.")

	# Add preview to scene (initially invisible)
	tower_preview_instance.visible = false
	add_child(tower_preview_instance) # Add to Main scene temporarily


func _is_placement_valid(preview_node: Node3D) -> bool:
	var overlap_area = preview_node.get_node_or_null("PlacementOverlapCheck")
	if not overlap_area:
		printerr("Placement validation failed: Preview node missing PlacementOverlapCheck Area3D")
		return false

	var overlapping_bodies = overlap_area.get_overlapping_bodies()
	var overlapping_areas = overlap_area.get_overlapping_areas()

	return overlapping_bodies.is_empty() and overlapping_areas.is_empty()


func _update_preview_material(is_valid: bool):
	if not tower_preview_instance: return
	var mesh_instance = tower_preview_instance.get_node_or_null("MeshInstance3D")
	if mesh_instance:
		mesh_instance.material_override = valid_placement_material if is_valid else invalid_placement_material


func _try_place_tower():
	if not is_placing_tower or not tower_preview_instance or not tower_preview_instance.visible:
		return

	if can_place_at_current_pos:
		if GameManager.spend_cash(tower_to_place_cost):
			print("Placing tower '%s' at: " % tower_to_place_name, tower_preview_instance.global_position)

			var final_tower = base_tower_scene.instantiate()
			if not final_tower:
				printerr("Failed to instantiate FINAL tower scene!")
				GameManager.increase_cash(tower_to_place_cost) # Refund
				_cancel_placement()
				return

			var upgrade_path = "000" # Base tower
			var final_stats_dict = TowerFactory.create_stats(tower_to_place_name, upgrade_path)

			if not final_stats_dict or not final_stats_dict.has("tower") or not final_stats_dict.has("projectile"):
				printerr("Failed to get FINAL stats from TowerFactory for: ", tower_to_place_name)
				if is_instance_valid(final_tower): final_tower.queue_free()
				GameManager.increase_cash(tower_to_place_cost) # Refund
				_cancel_placement()
				return

			final_tower.stats = final_stats_dict.tower
			final_tower.projectile_stats = final_stats_dict.projectile

			if final_tower.has_method("set_initial_state"):
				final_tower.set_initial_state(tower_to_place_name, tower_to_place_cost)
			else:
				printerr("Placed tower is missing 'set_initial_state' method!")

			final_tower.add_to_group("towers")
			towers_node.add_child(final_tower)
			final_tower.global_position = tower_preview_instance.global_position

			_cleanup_placement()
			if tower_placement_gui: tower_placement_gui.reset_status()
		else:
			print("Placement failed: Could not spend cash (final check).")
			if tower_placement_gui: tower_placement_gui.set_status("Error: Insufficient funds!", true)
	else:
		print("Cannot place tower here (invalid location).")
		if tower_placement_gui: tower_placement_gui.set_status("Cannot place here!", true)


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

# --- Upgrade/Sell Handlers ---

func _on_upgrade_requested(path_index: int, tier: int):
	if not is_instance_valid(currently_selected_tower):
		printerr("Upgrade requested but no tower selected or tower invalid.")
		return

	# 1. Get Upgrade Details from Factory
	var upgrade_details = TowerFactory.get_upgrade_details(currently_selected_tower.tower_name, path_index, tier)
	if upgrade_details.is_empty():
		printerr("Could not get upgrade details for %s path %d tier %d" % [currently_selected_tower.tower_name, path_index, tier])
		return

	var cost = upgrade_details.cost

	# 2. Check Affordability
	if not GameManager.can_afford(cost):
		print("Cannot afford upgrade.")
		# Re-display to potentially update button state (e.g., modulation)
		if tower_upgrade_gui: tower_upgrade_gui.display_tower(currently_selected_tower)
		return

	# 3. Spend Cash
	if GameManager.spend_cash(cost):
		# 4. Apply Upgrade on Tower Node
		if currently_selected_tower.has_method("apply_upgrade"):
			var success = currently_selected_tower.apply_upgrade(path_index, tier, cost)
			if success:
				print("Upgrade successful!")
				# 5. Update Upgrade GUI to reflect new state
				if tower_upgrade_gui: tower_upgrade_gui.display_tower(currently_selected_tower)
			else:
				printerr("Tower apply_upgrade method failed!")
				GameManager.increase_cash(cost) # Refund if apply failed
				# Re-display GUI after failed attempt
				if tower_upgrade_gui: tower_upgrade_gui.display_tower(currently_selected_tower)
		else:
			printerr("Selected tower does not have apply_upgrade method!")
			GameManager.increase_cash(cost) # Refund
	else:
		printerr("Failed to spend cash for upgrade even after checking affordability.")


func _on_sell_requested():
	if not is_instance_valid(currently_selected_tower):
		printerr("Sell requested but no tower selected or tower invalid.")
		return

	# 1. Calculate Sell Value
	var sell_value = 0
	# Use the stored total_spent value from the tower script
	if currently_selected_tower.has_meta("total_spent"): # Check if meta exists (or use property directly)
		sell_value = int(currently_selected_tower.total_spent * 0.7)
	elif currently_selected_tower.has_method("get") and currently_selected_tower.has("total_spent"): # Alternative check
		sell_value = int(currently_selected_tower.total_spent * 0.7)
	else:
		printerr("Could not get total_spent from tower to calculate sell value.")


	# 2. Increase Player Cash
	GameManager.increase_cash(sell_value)
	print("Sold tower %s for $%d" % [currently_selected_tower.name, sell_value])

	# 3. Store reference before deselecting
	var tower_to_remove = currently_selected_tower

	# 4. Deselect Tower (hides upgrade GUI)
	deselect_tower() # This now correctly hides the GUI

	# 5. Remove Tower from Scene
	if is_instance_valid(tower_to_remove):
		tower_to_remove.queue_free()
