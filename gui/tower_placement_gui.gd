# File: res://gui/tower_placement_gui.gd
extends Control

# Signal emitted when a tower button is pressed and affordable
signal tower_selected_for_placement(tower_name: String, cost: int)

# Define tower identifiers and costs
var basic_tower_name = "dart-monkey"
var basic_tower_cost = 100
# var other_tower_name = "tack-shooter"
# var other_tower_cost = 280

@onready var basic_tower_button: Button = %BasicTowerButton
@onready var status_label: Label = %StatusLabel
# @onready var other_tower_button: Button = %OtherTowerButton

func _ready():
	# Connect button signals using code
	if basic_tower_button:
		print("Attempting to connect button:", basic_tower_button) # Debug print
		if not basic_tower_button.pressed.is_connected(_on_tower_button_pressed):
			
			var err = basic_tower_button.pressed.connect(_on_tower_button_pressed.bind(basic_tower_name, basic_tower_cost))
			if err != OK:
				printerr("Failed to connect pressed signal for BasicTowerButton. Error code: ", err)
		# else: print("Signal already connected?") # Debug print
	else:
		printerr("Basic Tower Button node not found using %BasicTowerButton!")

	# Connect to GameManager to update button states based on cash
	if not GameManager.cash_changed.is_connected(_on_cash_changed):
		GameManager.cash_changed.connect(_on_cash_changed)
	print('Connections: ', basic_tower_button.pressed.get_connections())
	# Initial update
	_on_cash_changed(GameManager.cash)
	status_label.hide() # Hide status initially


func _on_tower_button_pressed(tower_name: String, cost: int):
	print("HANDLER CALLED! Tower button pressed. Name: ", tower_name, " Cost: ", cost) # Debug print
	if GameManager.can_afford(cost):
		print("Emitting tower_selected_for_placement signal...") # Debug print
		emit_signal("tower_selected_for_placement", tower_name, cost)
		status_label.text = "Placing %s... (LMB: Place, RMB: Cancel)" % tower_name.replace("-", " ").capitalize()
		status_label.show()
	else:
		print("Cannot afford tower.")
		status_label.text = "Not enough cash!"
		status_label.show()


func _on_cash_changed(new_cash: int):
	# Update button disabled state based on affordability
	if basic_tower_button:
		basic_tower_button.disabled = new_cash < basic_tower_cost
	# Update other buttons...


# Called by the placement manager when placement starts/ends
func set_status(text: String, pvisible: bool):
	status_label.text = text
	status_label.visible = pvisible


func reset_status():
	status_label.hide()
