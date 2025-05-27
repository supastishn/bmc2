# File: res://gui/tower_upgrade_gui.gd
extends Control

signal upgrade_requested(path_index: int, tier: int)
signal sell_requested()

@onready var tower_name_label: Label = %TowerNameLabel
@onready var upgrade_path_1_button: Button = %UpgradePath1Button
@onready var upgrade_path_2_button: Button = %UpgradePath2Button
@onready var upgrade_path_3_button: Button = %UpgradePath3Button
@onready var sell_button: Button = %SellButton

var _current_tower: Node = null
var _path_buttons: Array[Button] = []

func _ready():
	_path_buttons = [upgrade_path_1_button, upgrade_path_2_button, upgrade_path_3_button]
	# Connect sell button permanently
	if sell_button and not sell_button.pressed.is_connected(_on_sell_button_pressed):
		sell_button.pressed.connect(_on_sell_button_pressed)

	hide() # Start hidden


func display_tower(tower: Node):
	if not is_instance_valid(tower) or not tower.has_method("get_upgrade_path_string"):
		printerr("UpgradeGUI: Invalid tower passed to display_tower.")
		hide_panel()
		return

	_current_tower = tower
	var tower_display_name = tower.tower_name.replace("-", " ").capitalize()
	tower_name_label.text = "%s %s" % [tower_display_name, tower.get_upgrade_path_string()]

	# Update Sell Button
	var sell_value = int(tower.total_spent * 0.7) # Assuming 70% sell value
	sell_button.text = "Sell ($%d)" % sell_value

	# Update Upgrade Buttons
	for i in range(3):
		var path_index = i + 1
		var button = _path_buttons[i]
		var current_tier = tower.get_upgrade_level(path_index)
		var next_tier = current_tier + 1

		# Always clear any prior upgrade_requested binding in one call
		button


		if tower.is_path_locked(path_index) or next_tier > 5:
			button.disabled = true
			button.text = "Max Tier" if next_tier > 5 else "Locked"
		else:
			var upgrade_details = TowerFactory.get_upgrade_details(tower.tower_name, path_index, next_tier)
			if not upgrade_details.is_empty():
				var cost = upgrade_details.cost
				var uname = upgrade_details.name
				button.text = "%s\n$%d" % [uname, cost]
				button.disabled = false # Enable first

				# Check affordability and connect signal
				if GameManager.can_afford(cost):
					# Optional: Reset modulation if needed
					button.modulate = Color(1,1,1) # Normal color
					# Connect signal with bound arguments
					button.pressed.connect(_on_upgrade_button_pressed.bind(path_index, next_tier))
				else:
					# Optional: Dim button if unaffordable
					button.modulate = Color(0.6, 0.6, 0.6) # Dim color
					# Still connect the signal? Or leave it disconnected so clicking does nothing?
					# Let's connect it, the handler in Main.gd will re-check affordability.
					button.pressed.connect(_on_upgrade_button_pressed.bind(path_index, next_tier))

			else:
				# Upgrade details not found in factory (shouldn't happen)
				button.disabled = true
				button.text = "Error"
				printerr("Upgrade details missing for %s path %d tier %d" % [tower.tower_name, path_index, next_tier])

	show()


func hide_panel():
	_current_tower = null
	hide()


func _on_upgrade_button_pressed(path_index: int, tier: int):
	# Check if tower still exists before emitting
	if is_instance_valid(_current_tower):
		print("Upgrade button pressed: Path %d, Tier %d" % [path_index, tier])
		emit_signal("upgrade_requested", path_index, tier)
	else:
		print("Upgrade button pressed, but tower is no longer valid.")
		hide_panel()


func _on_sell_button_pressed():
	if is_instance_valid(_current_tower):
		print("Sell button pressed")
		emit_signal("sell_requested")
	else:
		print("Sell button pressed, but tower is no longer valid.")
		hide_panel()
