# File: res://gui/tower_upgrade_gui.gd
extends Control

## Emitted when an upgrade button is clicked and potentially affordable/valid.
signal upgrade_requested(path_index: int, tier: int)
## Emitted when the sell button is clicked.
signal sell_requested()

# Maximum tiers to display per path (adjust if needed)
const MAX_TIERS = 5

# References to UI elements (Use %UniqueNameInOwner if set up in scene)
@onready var tower_name_label: Label = %TowerNameLabel
@onready var sell_button: Button = %SellButton
# Store path VBoxContainers for easier access
@onready var path_vboxes: Array[VBoxContainer] = [ %Path1VBox, %Path2VBox, %Path3VBox ]

# Store button references dynamically
var upgrade_buttons: Array[Array] = [[], [], []] # [path_index][tier_index]

# Reference to the tower currently being displayed
var current_tower: Node3D = null

func _ready():
	# Populate the upgrade_buttons array
	for p_idx in range(3): # Path index 0, 1, 2
		if p_idx < path_vboxes.size() and path_vboxes[p_idx]:
			for t_idx in range(MAX_TIERS): # Tier index 0, 1, 2, 3, 4
				var button = path_vboxes[p_idx].get_child(t_idx) if t_idx < path_vboxes[p_idx].get_child_count() else null
				if button is Button:
					upgrade_buttons[p_idx].append(button)
					# Connect signal with bound arguments (path index + 1, tier + 1)
					button.pressed.connect(_on_upgrade_button_pressed.bind(p_idx + 1, t_idx + 1))
				else:
					# Add null placeholder if button doesn't exist for that tier
					upgrade_buttons[p_idx].append(null)
					if t_idx < path_vboxes[p_idx].get_child_count():
						printerr("Child %d in Path%dVBox is not a Button!" % [t_idx, p_idx+1])

	# Connect sell button
	if sell_button:
		sell_button.pressed.connect(_on_sell_button_pressed)
	else:
		printerr("Sell Button not found!")

	# Connect to GameManager cash changes to update button states
	GameManager.cash_changed.connect(_on_cash_changed)

	# Hide initially
	hide_panel()


## Populates the GUI with data from the selected tower.
func display_tower(tower: Node3D):
	if not is_instance_valid(tower) or not tower.has_method("get",): # Basic check
		printerr("UpgradeGUI: Invalid tower passed to display_tower.")
		hide_panel()
		return

	current_tower = tower
	var tower_base_name = current_tower.tower_name
	var current_path_str = current_tower.upgrade_path
	var current_path_array = [int(current_path_str[0]), int(current_path_str[1]), int(current_path_str[2])]
	var total_spent = current_tower.total_spent

	# Update Tower Name Label
	var display_name = TowerFactory.tower_data.get(tower_base_name, {}).get("display_name", tower_base_name.replace("-", " ").capitalize()) # Get a nicer name if defined
	tower_name_label.text = "%s %s" % [display_name, current_path_str]

	# Update Sell Button
	var sell_value = int(total_spent * 0.7) # Example: 70% sell value
	sell_button.text = "Sell ($%d)" % sell_value

	# Update Upgrade Buttons
	for p_idx in range(3): # Path index 0, 1, 2
		var path_current_tier = current_path_array[p_idx]
		for t_idx in range(MAX_TIERS): # Tier index 0, 1, 2, 3, 4
			var button: Button = upgrade_buttons[p_idx][t_idx] if t_idx < upgrade_buttons[p_idx].size() else null
			if not button: continue # Skip if button doesn't exist

			var target_tier = t_idx + 1
			var upgrade_details = TowerFactory.get_upgrade_details(tower_base_name, p_idx + 1, target_tier)

			if upgrade_details.is_empty():
				# No upgrade defined for this tier
				button.text = "N/A"
				button.disabled = true
				button.tooltip_text = ""
				continue

			var upgrade_name = upgrade_details.name
			var upgrade_cost = upgrade_details.cost

			button.text = "%s ($%d)" % [upgrade_name, upgrade_cost]
			button.tooltip_text = upgrade_name # Add description later if needed

			# --- Determine Button State (Disabled/Enabled) ---
			var can_afford = GameManager.can_afford(upgrade_cost)
			var is_purchased = target_tier <= path_current_tier
			var is_next_tier = target_tier == path_current_tier + 1
			var is_path_locked = _is_path_locked(current_path_array, p_idx + 1, target_tier) # Check BTD6 rules

			if is_purchased:
				button.disabled = true # Already have this upgrade
				# Optional: Add visual cue for purchased state (e.g., modulate color)
				button.modulate = Color(0.7, 0.7, 0.7)
			elif is_next_tier and not is_path_locked and can_afford:
				button.disabled = false # Can buy this upgrade
				button.modulate = Color(1.0, 1.0, 1.0)
			else:
				button.disabled = true # Cannot buy (locked, too expensive, or not next)
				button.modulate = Color(1.0, 1.0, 1.0) # Reset modulate if it was purchased before


	self.show()


## Hides the panel and clears the current tower reference.
func hide_panel():
	current_tower = null
	self.hide()


## Checks BTD6 cross-pathing rules.
func _is_path_locked(path_array: Array, target_path_idx: int, target_tier: int) -> bool:
	# Rule 1: Cannot upgrade past tier 2 if two *other* paths are already tier 2+
	if target_tier > 2:
		var other_paths_tier2_count = 0
		for i in range(3):
			if i != target_path_idx - 1 and path_array[i] >= 2:
				other_paths_tier2_count += 1
		if other_paths_tier2_count >= 2:
			return true # Locked

	# Rule 2: Cannot upgrade to tier 3+ if *another* path is already tier 3+
	if target_tier >= 3:
		var other_paths_tier3_count = 0
		for i in range(3):
			if i != target_path_idx - 1 and path_array[i] >= 3:
				other_paths_tier3_count += 1
		if other_paths_tier3_count >= 1:
			return true # Locked

	return false # Not locked by these rules


func _on_upgrade_button_pressed(path_index: int, tier: int):
	if not is_instance_valid(current_tower): return
	print("Upgrade button pressed: Path %d, Tier %d" % [path_index, tier])
	# Further checks (affordability, validity) happen in Main.gd handler
	emit_signal("upgrade_requested", path_index, tier)


func _on_sell_button_pressed():
	if not is_instance_valid(current_tower): return
	print("Sell button pressed for tower: ", current_tower.name)
	emit_signal("sell_requested")


func _on_cash_changed(new_cash: int):
	# If a tower is currently displayed, refresh its button states
	if is_instance_valid(current_tower) and self.visible:
		display_tower(current_tower) # Re-run display logic to update affordability
