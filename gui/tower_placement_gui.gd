# File: res://gui/tower_placement_gui.gd
extends Control

# Signal emitted when a tower button is pressed and affordable
signal tower_selected_for_placement(tower_name: String, cost: int)

# Define tower identifiers and costs
var basic_tower_name = "dart-monkey"
var basic_tower_cost = 200
var boomerang_name = "boomerang-monkey"
var boomerang_cost = 325
var bomb_name = "bomb-shooter"
var bomb_cost = 650
var tack_name = "tack-shooter"
var tack_cost = 300
var sniper_name = "sniper-monkey"
var sniper_cost = 300
var ninja_name = "ninja-monkey"
var ninja_cost = 425
var wizard_name = "wizard-monkey"
var wizard_cost = 450
var super_name = "super-monkey"
var super_cost = 2500

@onready var basic_tower_button: Button = %BasicTowerButton
@onready var status_label: Label = %StatusLabel
@onready var boomerang_button: Button = %BoomerangButton
@onready var bomb_button: Button = %BombButton
@onready var tack_button: Button = %TackButton
@onready var sniper_button: Button = %SniperButton
@onready var ninja_button: Button = %NinjaButton
@onready var wizard_button: Button = %WizardButton
@onready var super_button: Button = %SuperButton

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

	# Connect additional tower buttons if present
	if boomerang_button and not boomerang_button.pressed.is_connected(_on_tower_button_pressed):
		var e1 = boomerang_button.pressed.connect(_on_tower_button_pressed.bind(boomerang_name, boomerang_cost))
		if e1 != OK: printerr("Failed to connect BoomerangButton: ", e1)
	if bomb_button and not bomb_button.pressed.is_connected(_on_tower_button_pressed):
		var e2 = bomb_button.pressed.connect(_on_tower_button_pressed.bind(bomb_name, bomb_cost))
		if e2 != OK: printerr("Failed to connect BombButton: ", e2)
	if tack_button and not tack_button.pressed.is_connected(_on_tower_button_pressed):
		var e3 = tack_button.pressed.connect(_on_tower_button_pressed.bind(tack_name, tack_cost))
		if e3 != OK: printerr("Failed to connect TackButton: ", e3)
	if sniper_button and not sniper_button.pressed.is_connected(_on_tower_button_pressed):
		var e4 = sniper_button.pressed.connect(_on_tower_button_pressed.bind(sniper_name, sniper_cost))
		if e4 != OK: printerr("Failed to connect SniperButton: ", e4)
	if ninja_button and not ninja_button.pressed.is_connected(_on_tower_button_pressed):
		var e5 = ninja_button.pressed.connect(_on_tower_button_pressed.bind(ninja_name, ninja_cost))
		if e5 != OK: printerr("Failed to connect NinjaButton: ", e5)
	if wizard_button and not wizard_button.pressed.is_connected(_on_tower_button_pressed):
		var e6 = wizard_button.pressed.connect(_on_tower_button_pressed.bind(wizard_name, wizard_cost))
		if e6 != OK: printerr("Failed to connect WizardButton: ", e6)
	if super_button and not super_button.pressed.is_connected(_on_tower_button_pressed):
		var e7 = super_button.pressed.connect(_on_tower_button_pressed.bind(super_name, super_cost))
		if e7 != OK: printerr("Failed to connect SuperButton: ", e7)

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
	if boomerang_button:
		boomerang_button.disabled = new_cash < boomerang_cost
	if bomb_button:
		bomb_button.disabled = new_cash < bomb_cost
	if tack_button:
		tack_button.disabled = new_cash < tack_cost
	if sniper_button:
		sniper_button.disabled = new_cash < sniper_cost
	if ninja_button:
		ninja_button.disabled = new_cash < ninja_cost
	if wizard_button:
		wizard_button.disabled = new_cash < wizard_cost
	if super_button:
		super_button.disabled = new_cash < super_cost


# Called by the placement manager when placement starts/ends
func set_status(text: String, pvisible: bool):
	status_label.text = text
	status_label.visible = pvisible


func reset_status():
	status_label.hide()
