extends Control

@onready var lives_label: Label =  %LivesLabel # Adjust path as needed
@onready var cash_label: Label = %CashLabel   # Adjust path as needed
@onready var round_label: Label = %RoundLabel # NEW Round label
@onready var next_wave_button: Button = %NextWaveButton

func _ready():
	# Connect to GameManager signals
	GameManager.lives_changed.connect(_on_game_manager_lives_changed)
	GameManager.cash_changed.connect(_on_game_manager_cash_changed)
	GameManager.round_changed.connect(_on_game_manager_round_changed) # NEW Connection

	next_wave_button.hide()
	next_wave_button.pressed.connect(_on_next_wave_pressed)
	WaveManager.wave_spawning_complete.connect(_on_wave_ready)
	WaveManager.wave_cleared.connect(_on_wave_ready)

	# Initial update
	_on_game_manager_lives_changed(GameManager.lives)
	_on_game_manager_cash_changed(GameManager.cash)
	_on_game_manager_round_changed(GameManager.current_round) # NEW Initial update

func _on_game_manager_lives_changed(new_lives):
	lives_label.text = "Lives: %d" % new_lives

func _on_game_manager_cash_changed(new_cash):
	cash_label.text = "Cash: %d" % new_cash

# --- NEW: Update round display ---
func _on_game_manager_round_changed(new_round):
	round_label.text = "Round: %d" % new_round

func _on_wave_ready(round_number):
	# show button when either spawning or clearing finished
	next_wave_button.show()

func _on_next_wave_pressed():
	next_wave_button.hide()
	WaveManager.start_next_wave()
