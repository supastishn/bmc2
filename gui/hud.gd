
extends Control

@onready var lives_label: Label =  %LivesLabel # Adjust path as needed
@onready var cash_label: Label = %CashLabel   # Adjust path as needed

func _ready():
	# Connect to GameManager signals
	GameManager.lives_changed.connect(_on_game_manager_lives_changed)
	GameManager.cash_changed.connect(_on_game_manager_cash_changed)

	# Initial update
	_on_game_manager_lives_changed(GameManager.lives)
	_on_game_manager_cash_changed(GameManager.cash)

func _on_game_manager_lives_changed(new_lives):
	lives_label.text = "Lives: %d" % new_lives

func _on_game_manager_cash_changed(new_cash):
	cash_label.text = "Cash: %d" % new_cash
