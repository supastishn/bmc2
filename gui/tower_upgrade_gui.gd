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

    # Connect upgrade path buttons once; we reuse a single handler and metadata
    for b in _path_buttons:
        if b and not b.pressed.is_connected(_on_path_button_pressed):
            b.pressed.connect(_on_path_button_pressed.bind(b))

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

        # Default metadata setup for handler
        button.set_meta("path_index", path_index)
        button.set_meta("next_tier", next_tier)
        button.set_meta("cost", null)

        if tower.is_path_locked(path_index) or next_tier > 5:
            button.disabled = true
            button.text = "Max Tier" if next_tier > 5 else "Locked"
            button.modulate = Color(1,1,1)
        else:
            var upgrade_details = TowerFactory.get_upgrade_details(tower.tower_name, path_index, next_tier)
            if not upgrade_details.is_empty():
                var cost = int(upgrade_details.cost)
                var uname = str(upgrade_details.name)
                button.text = "%s\n$%d" % [uname, cost]
                button.disabled = false
                button.set_meta("cost", cost)

                if GameManager.can_afford(cost):
                    button.modulate = Color(1,1,1)
                else:
                    button.modulate = Color(0.6, 0.6, 0.6)
            else:
                button.disabled = true
                button.text = "Error"
                button.modulate = Color(1,1,1)
                printerr("Upgrade details missing for %s path %d tier %d" % [tower.tower_name, path_index, next_tier])

	show()


func hide_panel():
	_current_tower = null
	hide()


func _on_path_button_pressed(button: Button):
    if not is_instance_valid(_current_tower):
        print("Upgrade button pressed, but tower is no longer valid.")
        hide_panel()
        return

    var path_index: int = int(button.get_meta("path_index")) if button.has_meta("path_index") else -1
    var tier: int = int(button.get_meta("next_tier")) if button.has_meta("next_tier") else -1
    if path_index <= 0 or tier <= 0:
        printerr("Upgrade button missing metadata")
        return

    print("Upgrade button pressed: Path %d, Tier %d" % [path_index, tier])
    emit_signal("upgrade_requested", path_index, tier)


func _on_sell_button_pressed():
	if is_instance_valid(_current_tower):
		print("Sell button pressed")
		emit_signal("sell_requested")
	else:
		print("Sell button pressed, but tower is no longer valid.")
		hide_panel()
