# File: res://main/wave_manager.gd
extends Node

# Preload the base bloon scene used for all types
@export var base_bloon_scene: PackedScene = preload("res://bloon/bloon.tscn")
const BLOON_STATS_SCRIPT = preload("res://stats/bloon_stats.gd")

var path_node: Path3D # This will be set by main.gd

@onready var spawn_timer: Timer = $SpawnTimer
#@onready var wave_timer: Timer = $WaveTimer # Removed - waves advance immediately after spawning finishes

var current_wave_data = []
var current_wave_index = 0
var bloons_in_wave: Array[Dictionary] = [] # Holds {"stats_func": Callable, "delay": float}
var current_bloon_spawn_index: int = 0
var bloons_spawned_in_wave = 0
# --- NEW: Tracking active bloons ---
var active_bloons_in_current_round: int = 0
var spawning_complete_for_current_round: bool = false

const BASE_RED_SPEED = 2.0 # Define base speed for multipliers

func _ready():
	# Ensure timers exist and connect signals
	if not spawn_timer: spawn_timer = Timer.new(); spawn_timer.name = "SpawnTimer"; add_child(spawn_timer)
	spawn_timer.one_shot = true # Spawn one bloon per timeout
	if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout): spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	# Wave Data Structure using stats functions
	# 0-indexed array, where index `i` corresponds to round `i+1`
	current_wave_data = [
		# ... Add rounds 1 through 122 here if needed ...
		# --- Rounds 1-122 --- (Based on Standard BTD6 Rounds, delays are estimates)
		# Round 1 (Index 0): 20 Red
		[ {"stats_func": _get_blue_stats, "count": 20, "delay": 1.0} ],
		# Round 2 (Index 1): 35 Red
		[ {"stats_func": _get_red_stats, "count": 35, "delay": 0.8} ],
		# Round 3 (Index 2): 25 Red, 5 Blue
		[ {"stats_func": _get_red_stats, "count": 25, "delay": 0.7}, {"stats_func": _get_blue_stats, "count": 5, "delay": 1.0} ],
		# Round 4 (Index 3): 35 Red, 18 Blue
		[ {"stats_func": _get_red_stats, "count": 35, "delay": 0.5}, {"stats_func": _get_blue_stats, "count": 18, "delay": 0.7} ],
		# Round 5 (Index 4): 5 Red, 30 Blue
		[ {"stats_func": _get_red_stats, "count": 5, "delay": 0.8}, {"stats_func": _get_blue_stats, "count": 30, "delay": 0.6} ],
		# Round 6 (Index 5): 15 Red, 15 Blue, 4 Green
		[ {"stats_func": _get_red_stats, "count": 15, "delay": 0.5}, {"stats_func": _get_blue_stats, "count": 15, "delay": 0.5}, {"stats_func": _get_green_stats, "count": 4, "delay": 1.5} ],
		# Round 7 (Index 6): 20 Red, 20 Blue, 5 Green
		[ {"stats_func": _get_red_stats, "count": 20, "delay": 0.4}, {"stats_func": _get_blue_stats, "count": 20, "delay": 0.4}, {"stats_func": _get_green_stats, "count": 5, "delay": 1.2} ],
		# Round 8 (Index 7): 10 Red, 20 Blue, 14 Green
		[ {"stats_func": _get_red_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_blue_stats, "count": 20, "delay": 0.4}, {"stats_func": _get_green_stats, "count": 14, "delay": 0.7} ],
		# Round 9 (Index 8): 30 Green
		[ {"stats_func": _get_green_stats, "count": 30, "delay": 0.5} ],
		# Round 10 (Index 9): 102 Blue
		[ {"stats_func": _get_blue_stats, "count": 102, "delay": 0.2} ],
		# Round 11 (Index 10): 10 Red, 12 Blue, 15 Green, 3 Yellow
		[ {"stats_func": _get_red_stats, "count": 10, "delay": 0.4}, {"stats_func": _get_blue_stats, "count": 12, "delay": 0.4}, {"stats_func": _get_green_stats, "count": 15, "delay": 0.4}, {"stats_func": _get_yellow_stats, "count": 3, "delay": 1.0} ],
		# Round 12 (Index 11): 15 Blue, 10 Green, 5 Yellow
		[ {"stats_func": _get_blue_stats, "count": 15, "delay": 0.4}, {"stats_func": _get_green_stats, "count": 10, "delay": 0.6}, {"stats_func": _get_yellow_stats, "count": 5, "delay": 0.8} ],
		# Round 13 (Index 12): 50 Green, 23 Yellow
		[ {"stats_func": _get_green_stats, "count": 50, "delay": 0.2}, {"stats_func": _get_yellow_stats, "count": 23, "delay": 0.4} ],
		# Round 14 (Index 13): 49 Red, 15 Blue, 10 Green, 10 Yellow
		[ {"stats_func": _get_red_stats, "count": 49, "delay": 0.3}, {"stats_func": _get_blue_stats, "count": 15, "delay": 0.4}, {"stats_func": _get_green_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_yellow_stats, "count": 10, "delay": 0.6} ],
		# Round 15 (Index 14): 20 Red, 15 Blue, 12 Green, 10 Yellow, 5 Pink
		[ {"stats_func": _get_red_stats, "count": 20, "delay": 0.3}, {"stats_func": _get_blue_stats, "count": 15, "delay": 0.3}, {"stats_func": _get_green_stats, "count": 12, "delay": 0.3}, {"stats_func": _get_yellow_stats, "count": 10, "delay": 0.4}, {"stats_func": _get_pink_stats, "count": 5, "delay": 0.8} ],
		# Round 16 (Index 15): 40 Green, 18 Yellow
		[ {"stats_func": _get_green_stats, "count": 40, "delay": 0.3}, {"stats_func": _get_yellow_stats, "count": 18, "delay": 0.5} ],
		# Round 17 (Index 16): 12 Regrow Yellow
		[ {"stats_func": _get_regrow_yellow_stats, "count": 12, "delay": 0.7} ],
		# Round 18 (Index 17): 80 Green
		[ {"stats_func": _get_green_stats, "count": 80, "delay": 0.2} ],
		# Round 19 (Index 18): 10 Green, 5 Yellow, 15 Pink
		[ {"stats_func": _get_green_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_yellow_stats, "count": 5, "delay": 0.6}, {"stats_func": _get_pink_stats, "count": 15, "delay": 0.4} ],
		# Round 20 (Index 19): 6 Black
		[ {"stats_func": _get_black_stats, "count": 6, "delay": 1.0} ],
		# Round 21 (Index 20): 40 Yellow, 14 Pink
		[ {"stats_func": _get_yellow_stats, "count": 40, "delay": 0.3}, {"stats_func": _get_pink_stats, "count": 14, "delay": 0.5} ],
		# Round 22 (Index 21): 8 White
		[ {"stats_func": _get_white_stats, "count": 8, "delay": 1.0} ],
		# Round 23 (Index 22): 7 Black, 7 White
		[ {"stats_func": _get_black_stats, "count": 7, "delay": 0.8}, {"stats_func": _get_white_stats, "count": 7, "delay": 0.8} ],
		# Round 24 (Index 23): 1 Camo Green
		[ {"stats_func": _get_camo_green_stats, "count": 1, "delay": 0.0} ],
		# Round 25 (Index 24): 25 Yellow, 10 Purple
		[ {"stats_func": _get_yellow_stats, "count": 25, "delay": 0.3}, {"stats_func": _get_purple_stats, "count": 10, "delay": 0.5} ],
		# Round 26 (Index 25): 23 Pink, 4 Zebra
		[ {"stats_func": _get_pink_stats, "count": 23, "delay": 0.4}, {"stats_func": _get_zebra_stats, "count": 4, "delay": 1.2} ],
		# Round 27 (Index 26): 100 Red, 60 Blue, 45 Green, 45 Yellow
		[ {"stats_func": _get_red_stats, "count": 100, "delay": 0.1}, {"stats_func": _get_blue_stats, "count": 60, "delay": 0.1}, {"stats_func": _get_green_stats, "count": 45, "delay": 0.1}, {"stats_func": _get_yellow_stats, "count": 45, "delay": 0.1} ],
		# Round 28 (Index 27): 6 Lead
		[ {"stats_func": _get_lead_stats, "count": 6, "delay": 1.0} ],
		# Round 29 (Index 28): 50 Yellow
		[ {"stats_func": _get_yellow_stats, "count": 50, "delay": 0.3} ],
		# Round 30 (Index 29): 9 Lead
		[ {"stats_func": _get_lead_stats, "count": 9, "delay": 0.8} ],
		# Round 31 (Index 30): 8 Black, 8 White, 8 Zebra
		[ {"stats_func": _get_black_stats, "count": 8, "delay": 0.6}, {"stats_func": _get_white_stats, "count": 8, "delay": 0.6}, {"stats_func": _get_zebra_stats, "count": 8, "delay": 0.8} ],
		# Round 32 (Index 31): 15 Black, 10 White, 10 Purple
		[ {"stats_func": _get_black_stats, "count": 15, "delay": 0.4}, {"stats_func": _get_white_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_purple_stats, "count": 10, "delay": 0.6} ],
		# Round 33 (Index 32): 20 Camo Red
		[ {"stats_func": _get_camo_red_stats, "count": 20, "delay": 0.5} ],
		# Round 34 (Index 33): 120 Yellow, 8 Zebra
		[ {"stats_func": _get_yellow_stats, "count": 120, "delay": 0.1}, {"stats_func": _get_zebra_stats, "count": 8, "delay": 0.8} ],
		# Round 35 (Index 34): 35 Pink, 30 Black, 25 White, 5 Rainbow
		[ {"stats_func": _get_pink_stats, "count": 35, "delay": 0.2}, {"stats_func": _get_black_stats, "count": 30, "delay": 0.3}, {"stats_func": _get_white_stats, "count": 25, "delay": 0.4}, {"stats_func": _get_rainbow_stats, "count": 5, "delay": 1.0} ],
		# Round 36 (Index 35): 120 Regrow Pink
		[ {"stats_func": _get_regrow_pink_stats, "count": 120, "delay": 0.1} ],
		# Round 37 (Index 36): 25 Black, 25 White, 7 Camo White, 10 Lead
		[ {"stats_func": _get_black_stats, "count": 25, "delay": 0.3}, {"stats_func": _get_white_stats, "count": 25, "delay": 0.3}, {"stats_func": _get_camo_white_stats, "count": 7, "delay": 0.8}, {"stats_func": _get_lead_stats, "count": 10, "delay": 0.6} ],
		# Round 38 (Index 37): 42 Pink, 17 White, 10 Lead, 10 Zebra, 2 Ceramic
		[ {"stats_func": _get_pink_stats, "count": 42, "delay": 0.2}, {"stats_func": _get_white_stats, "count": 17, "delay": 0.3}, {"stats_func": _get_lead_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_zebra_stats, "count": 10, "delay": 0.6}, {"stats_func": _get_ceramic_stats, "count": 2, "delay": 2.0} ],
		# Round 39 (Index 38): 10 Black, 10 White, 20 Zebra, 18 Rainbow
		[ {"stats_func": _get_black_stats, "count": 10, "delay": 0.4}, {"stats_func": _get_white_stats, "count": 10, "delay": 0.4}, {"stats_func": _get_zebra_stats, "count": 20, "delay": 0.3}, {"stats_func": _get_rainbow_stats, "count": 18, "delay": 0.5} ],
		# Round 40 (Index 39): 1 MOAB
		[ {"stats_func": _get_moab_stats, "count": 1, "delay": 0.0} ],
		# Round 41 (Index 40): 60 Black, 70 Zebra
		[ {"stats_func": _get_black_stats, "count": 60, "delay": 0.1}, {"stats_func": _get_zebra_stats, "count": 70, "delay": 0.1} ],
		# Round 42 (Index 41): 6 Camo Rainbow, 6 Regrow Rainbow
		[ {"stats_func": _get_camo_rainbow_stats, "count": 6, "delay": 0.8}, {"stats_func": _get_regrow_rainbow_stats, "count": 6, "delay": 0.8} ],
		# Round 43 (Index 42): 10 Rainbow, 7 Ceramic
		[ {"stats_func": _get_rainbow_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_ceramic_stats, "count": 7, "delay": 1.0} ],
		# Round 44 (Index 43): 35 Zebra
		[ {"stats_func": _get_zebra_stats, "count": 35, "delay": 0.3} ],
		# Round 45 (Index 44): 75 Pink, 10 Purple, 4 Fortified Lead
		[ {"stats_func": _get_pink_stats, "count": 75, "delay": 0.1}, {"stats_func": _get_purple_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_fortified_lead_stats, "count": 4, "delay": 1.2} ],
		# Round 46 (Index 45): 1 Fortified Ceramic
		[ {"stats_func": _get_fortified_ceramic_stats, "count": 1, "delay": 0.0} ],
		# Round 47 (Index 46): 70 Camo Pink, 12 Ceramic
		[ {"stats_func": _get_camo_pink_stats, "count": 70, "delay": 0.1}, {"stats_func": _get_ceramic_stats, "count": 12, "delay": 0.6} ],
		# Round 48 (Index 47): 30 Camo Regrow Pink, 40 Regrow Purple, 10 Fortified Lead
		[ {"stats_func": _get_camo_regrow_pink_stats, "count": 30, "delay": 0.3}, {"stats_func": _get_regrow_purple_stats, "count": 40, "delay": 0.3} ],
		# Round 49 (Index 48): 343 Green, 20 Zebra, 20 Rainbow, 10 Ceramic, 18 Fortified Lead 
		# Note: Green count reduced for sanity, original is high RBE
		[ {"stats_func": _get_green_stats, "count": 150, "delay": 0.05}, {"stats_func": _get_zebra_stats, "count": 20, "delay": 0.3}, {"stats_func": _get_rainbow_stats, "count": 20, "delay": 0.3}, {"stats_func": _get_ceramic_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_fortified_lead_stats, "count": 18, "delay": 0.4} ],
		# Round 50 (Index 49): 20 Red, 5 Lead, 8 Ceramic, 2 MOAB
		[ {"stats_func": _get_red_stats, "count": 20, "delay": 0.2}, {"stats_func": _get_lead_stats, "count": 5, "delay": 0.8}, {"stats_func": _get_ceramic_stats, "count": 8, "delay": 0.7}, {"stats_func": _get_moab_stats, "count": 2, "delay": 3.0} ],
		# --- Rounds 51-122 ---
		# Round 51 (Index 50): 10 Ceramic, 10 Regrow Ceramic
		[ {"stats_func": _get_ceramic_stats, "count": 10, "delay": 0.8}, {"stats_func": _get_regrow_ceramic_stats, "count": 10, "delay": 0.8} ],
		# Round 52 (Index 51): 10 Rainbow, 15 Ceramic, 2 MOAB
		[ {"stats_func": _get_rainbow_stats, "count": 10, "delay": 0.4}, {"stats_func": _get_ceramic_stats, "count": 15, "delay": 0.6}, {"stats_func": _get_moab_stats, "count": 2, "delay": 2.5} ],
		# Round 53 (Index 52): 80 Camo Pink, 3 MOAB
		[ {"stats_func": _get_camo_pink_stats, "count": 80, "delay": 0.1}, {"stats_func": _get_moab_stats, "count": 3, "delay": 2.0} ],
		# Round 54 (Index 53): 35 Ceramic, 2 MOAB
		[ {"stats_func": _get_ceramic_stats, "count": 35, "delay": 0.3}, {"stats_func": _get_moab_stats, "count": 2, "delay": 2.0} ],
		# Round 55 (Index 54): 40 Ceramic, 1 MOAB
		[ {"stats_func": _get_ceramic_stats, "count": 40, "delay": 0.2}, {"stats_func": _get_moab_stats, "count": 1, "delay": 3.0} ],
		# Round 56 (Index 55): 40 Camo Rainbow, 1 MOAB
		[ {"stats_func": _get_camo_rainbow_stats, "count": 40, "delay": 0.2}, {"stats_func": _get_moab_stats, "count": 1, "delay": 3.0} ],
		# Round 57 (Index 56): 40 Rainbow, 2 MOAB
		[ {"stats_func": _get_rainbow_stats, "count": 40, "delay": 0.2}, {"stats_func": _get_moab_stats, "count": 2, "delay": 2.0} ],
		# Round 58 (Index 57): 15 Ceramic, 10 Fortified Ceramic, 2 MOAB
		[ {"stats_func": _get_ceramic_stats, "count": 15, "delay": 0.4}, {"stats_func": _get_fortified_ceramic_stats, "count": 10, "delay": 0.6}, {"stats_func": _get_moab_stats, "count": 2, "delay": 2.0} ],
		# Round 59 (Index 58): 50 Camo Lead, 20 Ceramic
		[ {"stats_func": _get_camo_lead_stats, "count": 50, "delay": 0.1}, {"stats_func": _get_ceramic_stats, "count": 20, "delay": 0.4} ],
		# Round 60 (Index 59): 1 BFB
		[ {"stats_func": _get_bfb_stats, "count": 1, "delay": 0.0} ],
		# Round 61 (Index 60): 150 Regrow Zebra, 3 MOAB
		[ {"stats_func": _get_regrow_zebra_stats, "count": 150, "delay": 0.1}, {"stats_func": _get_moab_stats, "count": 3, "delay": 1.5} ],
		# Round 62 (Index 61): 250 Purple, 15 Camo Purple, 5 MOAB
		[ {"stats_func": _get_purple_stats, "count": 250, "delay": 0.05}, {"stats_func": _get_camo_purple_stats, "count": 15, "delay": 0.3}, {"stats_func": _get_moab_stats, "count": 5, "delay": 1.0} ],
		# Round 63 (Index 62): 75 Lead, 122 Ceramic, 3 MOAB
		[ {"stats_func": _get_lead_stats, "count": 75, "delay": 0.05}, {"stats_func": _get_ceramic_stats, "count": 122, "delay": 0.05}, {"stats_func": _get_moab_stats, "count": 3, "delay": 1.0} ],
		# Round 64 (Index 63): 6 MOAB, 4 Fortified MOAB
		[ {"stats_func": _get_moab_stats, "count": 6, "delay": 0.8}, {"stats_func": _get_fortified_moab_stats, "count": 4, "delay": 1.2} ],
		# Round 65 (Index 64): 100 Zebra, 70 Rainbow, 50 Ceramic, 3 MOAB, 2 BFB
		[ {"stats_func": _get_zebra_stats, "count": 100, "delay": 0.05}, {"stats_func": _get_rainbow_stats, "count": 70, "delay": 0.1}, {"stats_func": _get_ceramic_stats, "count": 50, "delay": 0.15}, {"stats_func": _get_moab_stats, "count": 3, "delay": 1.0}, {"stats_func": _get_bfb_stats, "count": 2, "delay": 2.0} ],
		# Round 66 (Index 65): 8 MOAB
		[ {"stats_func": _get_moab_stats, "count": 8, "delay": 0.6} ],
		# Round 67 (Index 66): 13 Camo Regrow Rainbow
		[ {"stats_func": _get_camo_regrow_rainbow_stats, "count": 13, "delay": 0.5} ],
		# Round 68 (Index 67): 4 MOAB, 1 BFB
		[ {"stats_func": _get_moab_stats, "count": 4, "delay": 0.8}, {"stats_func": _get_bfb_stats, "count": 1, "delay": 2.0} ],
		# Round 69 (Index 68): 40 Regrow Black, 40 Lead, 50 Ceramic
		[ {"stats_func": _get_regrow_black_stats, "count": 40, "delay": 0.1}, {"stats_func": _get_lead_stats, "count": 40, "delay": 0.1}, {"stats_func": _get_ceramic_stats, "count": 50, "delay": 0.2} ],
		# Round 70 (Index 69): 12 Camo Rainbow, 200 Regrow White, 4 MOAB
		[ {"stats_func": _get_camo_rainbow_stats, "count": 12, "delay": 0.4}, {"stats_func": _get_regrow_white_stats, "count": 200, "delay": 0.05}, {"stats_func": _get_moab_stats, "count": 4, "delay": 1.0} ],
		# Round 71 (Index 70): 30 Ceramic, 10 MOAB
		[ {"stats_func": _get_ceramic_stats, "count": 30, "delay": 0.3}, {"stats_func": _get_moab_stats, "count": 10, "delay": 0.7} ],
		# Round 72 (Index 71): 38 Regrow Ceramic, 2 BFB
		[ {"stats_func": _get_regrow_ceramic_stats, "count": 38, "delay": 0.2}, {"stats_func": _get_bfb_stats, "count": 2, "delay": 2.0} ],
		# Round 73 (Index 72): 8 MOAB, 2 BFB
		[ {"stats_func": _get_moab_stats, "count": 8, "delay": 0.6}, {"stats_func": _get_bfb_stats, "count": 2, "delay": 2.0} ],
		# Round 74 (Index 73): 50 Camo Green, 100 Ceramic, 1 BFB
		[ {"stats_func": _get_camo_green_stats, "count": 50, "delay": 0.1}, {"stats_func": _get_ceramic_stats, "count": 100, "delay": 0.1}, {"stats_func": _get_bfb_stats, "count": 1, "delay": 2.0} ],
		# Round 75 (Index 74): 14 Lead, 14 Fortified Lead, 5 MOAB, 1 BFB, 3 Fortified MOAB
		[ {"stats_func": _get_lead_stats, "count": 14, "delay": 0.4}, {"stats_func": _get_fortified_lead_stats, "count": 14, "delay": 0.4}, {"stats_func": _get_moab_stats, "count": 5, "delay": 0.8}, {"stats_func": _get_bfb_stats, "count": 1, "delay": 2.0}, {"stats_func": _get_fortified_moab_stats, "count": 3, "delay": 1.5} ],
		# Round 76 (Index 75): 60 Regrow Ceramic
		[ {"stats_func": _get_regrow_ceramic_stats, "count": 60, "delay": 0.1} ],
		# Round 77 (Index 76): 11 MOAB, 5 BFB
		[ {"stats_func": _get_moab_stats, "count": 11, "delay": 0.5}, {"stats_func": _get_bfb_stats, "count": 5, "delay": 1.5} ],
		# Round 78 (Index 77): 75 Purple, 80 Ceramic, 1 BFB, 6 Camo Rainbow
		[ {"stats_func": _get_purple_stats, "count": 75, "delay": 0.05}, {"stats_func": _get_ceramic_stats, "count": 80, "delay": 0.05}, {"stats_func": _get_bfb_stats, "count": 1, "delay": 1.0}, {"stats_func": _get_camo_rainbow_stats, "count": 6, "delay": 0.5} ],
		# Round 79 (Index 78): 500 Regrow Rainbow, 40 Fortified Ceramic, 10 BFB, 2 Fortified MOAB
		# Note: Rainbow count reduced
		[ {"stats_func": _get_regrow_rainbow_stats, "count": 200, "delay": 0.02}, {"stats_func": _get_fortified_ceramic_stats, "count": 40, "delay": 0.2}, {"stats_func": _get_bfb_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_fortified_moab_stats, "count": 2, "delay": 1.0} ],
		# Round 80 (Index 79): 1 ZOMG
		[ {"stats_func": _get_zomg_stats, "count": 1, "delay": 0.0} ],
		# Round 81 (Index 80): 10 BFB
		[ {"stats_func": _get_bfb_stats, "count": 10, "delay": 0.6} ],
		# Round 82 (Index 81): 15 BFB, 5 Fortified MOAB
		[ {"stats_func": _get_bfb_stats, "count": 15, "delay": 0.5}, {"stats_func": _get_fortified_moab_stats, "count": 5, "delay": 1.0} ],
		# Round 83 (Index 82): 40 Ceramic, 40 Regrow Ceramic, 10 MOAB
		[ {"stats_func": _get_ceramic_stats, "count": 40, "delay": 0.1}, {"stats_func": _get_regrow_ceramic_stats, "count": 40, "delay": 0.1}, {"stats_func": _get_moab_stats, "count": 10, "delay": 0.5} ],
		# Round 84 (Index 83): 50 MOAB, 10 BFB
		[ {"stats_func": _get_moab_stats, "count": 50, "delay": 0.2}, {"stats_func": _get_bfb_stats, "count": 10, "delay": 0.6} ],
		# Round 85 (Index 84): 2 ZOMG
		[ {"stats_func": _get_zomg_stats, "count": 2, "delay": 2.0} ],
		# Round 86 (Index 85): 5 BFB
		[ {"stats_func": _get_bfb_stats, "count": 5, "delay": 1.0} ],
		# Round 87 (Index 86): 4 ZOMG
		[ {"stats_func": _get_zomg_stats, "count": 4, "delay": 1.5} ],
		# Round 88 (Index 87): 18 MOAB, 6 BFB, 2 ZOMG
		[ {"stats_func": _get_moab_stats, "count": 18, "delay": 0.3}, {"stats_func": _get_bfb_stats, "count": 6, "delay": 0.8}, {"stats_func": _get_zomg_stats, "count": 2, "delay": 2.0} ],
		# Round 89 (Index 88): 10 Fortified BFB
		[ {"stats_func": _get_fortified_bfb_stats, "count": 10, "delay": 0.6} ],
		# Round 90 (Index 89): 3 DDT
		[ {"stats_func": _get_ddt_stats, "count": 3, "delay": 1.5} ],
		# Round 91 (Index 90): 100 Fortified Ceramic, 10 BFB
		[ {"stats_func": _get_fortified_ceramic_stats, "count": 100, "delay": 0.05}, {"stats_func": _get_bfb_stats, "count": 10, "delay": 0.5} ],
		# Round 92 (Index 91): 8 ZOMG, 150 Purple
		[ {"stats_func": _get_zomg_stats, "count": 8, "delay": 0.8}, {"stats_func": _get_purple_stats, "count": 150, "delay": 0.05} ],
		# Round 93 (Index 92): 10 Fortified BFB, 6 DDT
		[ {"stats_func": _get_fortified_bfb_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_ddt_stats, "count": 6, "delay": 1.0} ],
		# Round 94 (Index 93): 15 ZOMG
		[ {"stats_func": _get_zomg_stats, "count": 15, "delay": 0.5} ],
		# Round 95 (Index 94): 500 Camo Regrow Purple, 250 DDT, 30 DDT
		# Note: Purple count reduced
		[ {"stats_func": _get_camo_regrow_purple_stats, "count": 200, "delay": 0.02}, {"stats_func": _get_ddt_stats, "count": 30, "delay": 0.4} ],
		# Round 96 (Index 95): 6 Fortified MOAB, 10 Fortified BFB, 6 ZOMG
		[ {"stats_func": _get_fortified_moab_stats, "count": 6, "delay": 0.8}, {"stats_func": _get_fortified_bfb_stats, "count": 10, "delay": 0.6}, {"stats_func": _get_zomg_stats, "count": 6, "delay": 1.0} ],
		# Round 97 (Index 96): 2 Fortified ZOMG
		[ {"stats_func": _get_fortified_zomg_stats, "count": 2, "delay": 2.0} ],
		# Round 98 (Index 97): 30 BFB, 8 ZOMG
		[ {"stats_func": _get_bfb_stats, "count": 30, "delay": 0.2}, {"stats_func": _get_zomg_stats, "count": 8, "delay": 0.7} ],
		# Round 99 (Index 98): 9 Fortified DDT, 3 Fortified ZOMG
		[ {"stats_func": _get_fortified_ddt_stats, "count": 9, "delay": 0.5}, {"stats_func": _get_fortified_zomg_stats, "count": 3, "delay": 1.5} ],
		# Round 100 (Index 99): 1 BAD
		[ {"stats_func": _get_bad_stats, "count": 1, "delay": 0.0} ],
		# Round 101 (Index 100): 50 Fortified Purple, 100 Fortified Lead, 20 Fortified Ceramic
		[ {"stats_func": _get_fortified_purple_stats, "count": 50, "delay": 0.1}, {"stats_func": _get_fortified_lead_stats, "count": 100, "delay": 0.1}, {"stats_func": _get_fortified_ceramic_stats, "count": 20, "delay": 0.3} ],
		# Round 102 (Index 101): 25 Fortified MOAB, 1 ZOMG
		[ {"stats_func": _get_fortified_moab_stats, "count": 25, "delay": 0.3}, {"stats_func": _get_zomg_stats, "count": 1, "delay": 2.0} ],
		# Round 103 (Index 102): 200 Fortified Ceramic, 6 ZOMG
		[ {"stats_func": _get_fortified_ceramic_stats, "count": 200, "delay": 0.05}, {"stats_func": _get_zomg_stats, "count": 6, "delay": 0.8} ],
		# Round 104 (Index 103): 500 Camo Regrow Pink, 30 Fortified MOAB, 100 Fortified Lead
		# Note: Pink count reduced
		[ {"stats_func": _get_camo_regrow_pink_stats, "count": 200, "delay": 0.02}, {"stats_func": _get_fortified_moab_stats, "count": 30, "delay": 0.3}, {"stats_func": _get_fortified_lead_stats, "count": 100, "delay": 0.1} ],
		# Round 105 (Index 104): 200 Fortified Ceramic, 100 Purple, 10 Fortified BFB
		[ {"stats_func": _get_fortified_ceramic_stats, "count": 200, "delay": 0.05}, {"stats_func": _get_purple_stats, "count": 100, "delay": 0.1}, {"stats_func": _get_fortified_bfb_stats, "count": 10, "delay": 0.5} ],
		# Round 106 (Index 105): 15 DDT, 15 Fortified DDT
		[ {"stats_func": _get_ddt_stats, "count": 15, "delay": 0.4}, {"stats_func": _get_fortified_ddt_stats, "count": 15, "delay": 0.4} ],
		# Round 107 (Index 106): 25 BFB, 10 Fortified BFB
		[ {"stats_func": _get_bfb_stats, "count": 25, "delay": 0.3}, {"stats_func": _get_fortified_bfb_stats, "count": 10, "delay": 0.5} ],
		# Round 108 (Index 107): 12 ZOMG
		[ {"stats_func": _get_zomg_stats, "count": 12, "delay": 0.6} ],
		# Round 109 (Index 108): 60 Fortified Ceramic, 10 Fortified MOAB, 10 Fortified BFB
		[ {"stats_func": _get_fortified_ceramic_stats, "count": 60, "delay": 0.1}, {"stats_func": _get_fortified_moab_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_fortified_bfb_stats, "count": 10, "delay": 0.6} ],
		# Round 110 (Index 109): 50 MOAB, 15 Fortified MOAB
		[ {"stats_func": _get_moab_stats, "count": 50, "delay": 0.2}, {"stats_func": _get_fortified_moab_stats, "count": 15, "delay": 0.4} ],
		# Round 111 (Index 110): 30 BFB
		[ {"stats_func": _get_bfb_stats, "count": 30, "delay": 0.3} ],
		# Round 112 (Index 111): 150 Fortified Ceramic, 20 Fortified MOAB
		[ {"stats_func": _get_fortified_ceramic_stats, "count": 150, "delay": 0.05}, {"stats_func": _get_fortified_moab_stats, "count": 20, "delay": 0.4} ],
		# Round 113 (Index 112): 15 ZOMG
		[ {"stats_func": _get_zomg_stats, "count": 15, "delay": 0.5} ],
		# Round 114 (Index 113): 10 MOAB, 10 BFB, 10 ZOMG
		[ {"stats_func": _get_moab_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_bfb_stats, "count": 10, "delay": 0.6}, {"stats_func": _get_zomg_stats, "count": 10, "delay": 0.7} ],
		# Round 115 (Index 114): 20 DDT, 10 Fortified DDT, 5 BFB
		[ {"stats_func": _get_ddt_stats, "count": 20, "delay": 0.3}, {"stats_func": _get_fortified_ddt_stats, "count": 10, "delay": 0.4}, {"stats_func": _get_bfb_stats, "count": 5, "delay": 0.8} ],
		# Round 116 (Index 115): 8 Fortified ZOMG
		[ {"stats_func": _get_fortified_zomg_stats, "count": 8, "delay": 0.8} ],
		# Round 117 (Index 116): 18 Fortified BFB
		[ {"stats_func": _get_fortified_bfb_stats, "count": 18, "delay": 0.4} ],
		# Round 118 (Index 117): 20 MOAB, 20 Fortified MOAB
		[ {"stats_func": _get_moab_stats, "count": 20, "delay": 0.3}, {"stats_func": _get_fortified_moab_stats, "count": 20, "delay": 0.3} ],
		# Round 119 (Index 118): 10 BFB, 10 Fortified BFB, 2 Fortified ZOMG
		[ {"stats_func": _get_bfb_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_fortified_bfb_stats, "count": 10, "delay": 0.5}, {"stats_func": _get_fortified_zomg_stats, "count": 2, "delay": 2.0} ],
		# Round 120 (Index 119): 2 BAD
		[ {"stats_func": _get_bad_stats, "count": 2, "delay": 3.0} ],
		# Round 121 (Index 120): 12 Fortified DDT, 6 Fortified ZOMG
		[ {"stats_func": _get_fortified_ddt_stats, "count": 12, "delay": 0.4}, {"stats_func": _get_fortified_zomg_stats, "count": 6, "delay": 1.0} ],
		# Round 122 (Index 121): 3 BAD
		[ {"stats_func": _get_bad_stats, "count": 3, "delay": 2.5} ],
		# --- Rounds 123-140 ---
		# Round 123 (index 122): 8 Fortified ZOMGs, 200 MOABs
		[ {"stats_func": _get_fortified_zomg_stats, "count": 8, "delay": 1.0}, {"stats_func": _get_moab_stats, "count": 200, "delay": 0.1} ],
		# Round 124 (index 123): 75 Fortified BFBs
		[ {"stats_func": _get_fortified_bfb_stats, "count": 75, "delay": 0.2} ],
		# Round 125 (index 124): 21 ZOMGs, 42 BFBs, 63 MOABs
		[ {"stats_func": _get_zomg_stats, "count": 21, "delay": 0.8}, {"stats_func": _get_bfb_stats, "count": 42, "delay": 0.4}, {"stats_func": _get_moab_stats, "count": 63, "delay": 0.2} ],
		# Round 126 (index 125): 1 Fortified Camo Regrow Lead, 99 DDTs
		[ {"stats_func": _get_fortified_camo_regrow_lead_stats, "count": 1, "delay": 5.0}, {"stats_func": _get_ddt_stats, "count": 99, "delay": 0.1} ],
		# Round 127 (index 126): 48 MOABs, 24 BFBs
		[ {"stats_func": _get_moab_stats, "count": 48, "delay": 0.3}, {"stats_func": _get_bfb_stats, "count": 24, "delay": 0.6} ],
		# Round 128 (index 127): 39 Fortified DDTs, 200 Fortified Camo Ceramics, 30 BFBs
		[ {"stats_func": _get_fortified_ddt_stats, "count": 39, "delay": 0.4}, {"stats_func": _get_fortified_camo_ceramic_stats, "count": 200, "delay": 0.05}, {"stats_func": _get_bfb_stats, "count": 30, "delay": 0.8} ],
		# Round 129 (index 128): 7 Fortified ZOMGs, 77 Fortified Camo Leads, 77 Camo Purples, 77 Camo Ceramics, 7 ZOMGs, 18 DDTs
		[
			{"stats_func": _get_fortified_zomg_stats, "count": 7, "delay": 2.0},
			{"stats_func": _get_fortified_camo_lead_stats, "count": 77, "delay": 0.2},
			{"stats_func": _get_camo_purple_stats, "count": 77, "delay": 0.2},
			{"stats_func": _get_camo_ceramic_stats, "count": 77, "delay": 0.2},
			{"stats_func": _get_zomg_stats, "count": 7, "delay": 2.0},
			{"stats_func": _get_ddt_stats, "count": 18, "delay": 0.8},
		],
		# Round 130 (index 129): 84 MOABs, 66 Fortified MOABs, 48 DDTs, 6 Fortified DDTs
		[
			{"stats_func": _get_moab_stats, "count": 84, "delay": 0.15},
			{"stats_func": _get_fortified_moab_stats, "count": 66, "delay": 0.2},
			{"stats_func": _get_ddt_stats, "count": 48, "delay": 0.3},
			{"stats_func": _get_fortified_ddt_stats, "count": 6, "delay": 1.0},
		],
		# Round 131 (index 130): 18 Fortified ZOMGs
		[ {"stats_func": _get_fortified_zomg_stats, "count": 18, "delay": 0.9} ],
		# Round 132 (index 131): 18 ZOMGs, 6 Fortified ZOMGs, 200 Camo Purples
		[ {"stats_func": _get_zomg_stats, "count": 18, "delay": 0.9}, {"stats_func": _get_fortified_zomg_stats, "count": 6, "delay": 1.5}, {"stats_func": _get_camo_purple_stats, "count": 200, "delay": 0.05} ],
		# Round 133 (index 132): 12 Fortified MOABs, 12 Fortified BFBs, 4 Fortified ZOMGs, 27 MOABs, 27 BFBs, 9 ZOMGs
		[
			{"stats_func": _get_fortified_moab_stats, "count": 12, "delay": 0.5},
			{"stats_func": _get_fortified_bfb_stats, "count": 12, "delay": 0.8},
			{"stats_func": _get_fortified_zomg_stats, "count": 4, "delay": 1.5},
			{"stats_func": _get_moab_stats, "count": 27, "delay": 0.3},
			{"stats_func": _get_bfb_stats, "count": 27, "delay": 0.6},
			{"stats_func": _get_zomg_stats, "count": 9, "delay": 1.0},
		],
		# Round 134 (index 133): 12 Fortified BFBs, 28 BFBs
		[ {"stats_func": _get_fortified_bfb_stats, "count": 12, "delay": 0.8}, {"stats_func": _get_bfb_stats, "count": 28, "delay": 0.5} ],
		# Round 135 (index 134): 14 Fortified ZOMGs, 21 Fortified DDTs
		[ {"stats_func": _get_fortified_zomg_stats, "count": 14, "delay": 1.0}, {"stats_func": _get_fortified_ddt_stats, "count": 21, "delay": 0.5} ],
		# Round 136 (index 135): 96 Fortified MOABs, 24 BFBs
		[ {"stats_func": _get_fortified_moab_stats, "count": 96, "delay": 0.1}, {"stats_func": _get_bfb_stats, "count": 24, "delay": 0.6} ],
		# Round 137 (index 136): 18 ZOMGs, 24 BFBs, 48 MOABs
		[ {"stats_func": _get_zomg_stats, "count": 18, "delay": 0.8}, {"stats_func": _get_bfb_stats, "count": 24, "delay": 0.6}, {"stats_func": _get_moab_stats, "count": 48, "delay": 0.3} ],
		# Round 138 (index 137): 81 Fortified DDTs, 45 DDTs
		[ {"stats_func": _get_fortified_ddt_stats, "count": 81, "delay": 0.15}, {"stats_func": _get_ddt_stats, "count": 45, "delay": 0.25} ],
		# Round 139 (index 138): 181 MOABs, 72 Fortified MOABs
		[ {"stats_func": _get_moab_stats, "count": 181, "delay": 0.05}, {"stats_func": _get_fortified_moab_stats, "count": 72, "delay": 0.1} ],
		# Round 140 (index 139): 1 Fortified BAD, 1 BAD
		[ {"stats_func": _get_fortified_bad_stats, "count": 1, "delay": 10.0}, {"stats_func": _get_bad_stats, "count": 1, "delay": 5.0} ],
	]
	start_next_wave()


func start_next_wave():
	# --- Advance Round Number ---
	GameManager.advance_round() # Advance round counter for the wave *about* to start
	# Adjust wave starting logic if necessary - assuming current_wave_index maps 0-based
	print("Attempting to start wave for index: ", current_wave_index)
	if current_wave_index >= len(current_wave_data):
		print("All waves finished!")
		return

	print("Starting Wave ", current_wave_index + 1)
	bloons_spawned_in_wave = 0
	# --- NEW: Prepare the flat list of bloons for the current wave ---
	# --- NEW: Reset tracking for the new wave ---
	active_bloons_in_current_round = 0 # Will be incremented as they spawn
	spawning_complete_for_current_round = false

	bloons_in_wave.clear()
	var wave_groups = current_wave_data[current_wave_index]
	for group in wave_groups:
		var stats_func: Callable = group["stats_func"]
		var count: int = group["count"]
		var delay: float = group["delay"]
		for i in range(count):
			bloons_in_wave.append({"stats_func": stats_func, "delay": delay})

	current_bloon_spawn_index = 0
	_on_spawn_timer_timeout()


func _on_spawn_timer_timeout():
	# Check if spawning for the current wave is actually finished
	if current_bloon_spawn_index >= bloons_in_wave.size():
		if not spawning_complete_for_current_round: # Only set flag once
			print("Wave ", current_wave_index + 1, " spawning finished.")
			spawning_complete_for_current_round = true
			current_wave_index += 1 # Increment for the next wave
			start_next_wave() # Immediately trigger the next wave setup
		return # Stop spawning for this iteration

	# Spawn the next bloon in the list
	var bloon_info = bloons_in_wave[current_bloon_spawn_index]
	var stats_func: Callable = bloon_info["stats_func"]
	var bloon_stats: BloonStats = stats_func.call() # Call the function to get stats
	spawn_bloon(bloon_stats)
	current_bloon_spawn_index += 1

	# Schedule next spawn (if there is one)
	if current_bloon_spawn_index < bloons_in_wave.size():
		spawn_timer.wait_time = bloon_info["delay"] # Use delay from the bloon just spawned
		spawn_timer.start()
	else:
		# This was the last bloon for this wave.
		# Mark spawning as complete, increment index, and trigger the next wave start immediately.
		print("Wave ", current_wave_index + 1, " spawning finished (last bloon).")
		spawning_complete_for_current_round = true
		current_wave_index += 1
		start_next_wave()


	# This else block might be redundant now due to the check at the start
	# else:
		# Wave finished spawning, start timer for the next wave
		# print("Wave ", wave_index + 1, " spawning complete.")
		# wave_index += 1
		# wave_timer.start()


func spawn_bloon(bloon_stats_resource: BloonStats, p_progress_ratio: float = 0.0): # Added progress ratio param
	if not path_node: printerr("Path node not set in WaveManager!"); return
	if not base_bloon_scene: printerr("Base Bloon Scene not set in WaveManager!"); return
	if not bloon_stats_resource or not bloon_stats_resource is BloonStats: # Check type
		printerr("Invalid BloonStats resource provided to spawn_bloon!")
		return

	# --- Request Bloon from Pool ---
	# We always use the base scene, the stats resource defines the type
	var bloon_instance: Node = NodePoolManager.request_node(base_bloon_scene) # Changed type hint
	if not bloon_instance:
		printerr("WaveManager failed to get bloon from pool/fallback!")
		return # Failed to get a bloon

	# --- NEW: Increment active bloon count ---
	active_bloons_in_current_round += 1
	# print_debug("Spawned bloon, active count: ", active_bloons_in_current_round)

	# --- Add to Scene and Configure ---
	# Assign stats directly. The pool_reset should handle applying them internally if needed.
	bloon_instance.stats = bloon_stats_resource

	path_node.add_child(bloon_instance)
	# --- NEW: Set progress ratio for children ---
	if p_progress_ratio > 0.0 and bloon_instance is PathFollow3D:
		bloon_instance.progress_ratio = p_progress_ratio

	# --- NEW: Connect child spawning signal ---
	if not bloon_instance.spawn_children_requested.is_connected(_on_bloon_spawn_children):
		bloon_instance.spawn_children_requested.connect(_on_bloon_spawn_children)
	# --- NEW: Connect bloon removal signal ---
	if not bloon_instance.bloon_removed_from_play.is_connected(_on_bloon_removed):
		bloon_instance.bloon_removed_from_play.connect(_on_bloon_removed)

	# The bloon's pool_reset() should handle setting progress to 0.
	# No further setup needed here unless you have wave-specific modifications.

# --- NEW: Handle Bloon Removal ---
func _on_bloon_removed():
	if active_bloons_in_current_round > 0:
		active_bloons_in_current_round -= 1
		# print_debug("Bloon removed, active count: ", active_bloons_in_current_round)
		_check_round_clear() # Check if the field is now clear
	# else: print_debug("Bloon removed, but active count was already 0?") # Should not happen ideally

# --- NEW: Check if the Round Should End ---
# --- RENAMED: Check if the Round *field* is clear ---
func _check_round_clear():
	# Field is clear if spawning is complete AND no active bloons remain
	if spawning_complete_for_current_round and active_bloons_in_current_round == 0:
		print("All bloons cleared for wave ", current_wave_index + 1)
		# No longer advances round or starts timer here

# --- NEW: Child Spawning Handler ---
func _on_bloon_spawn_children(children_stats_array: Array, spawn_progress_ratio: float):
	for child_stats in children_stats_array:
		if child_stats is BloonStats:
			spawn_bloon(child_stats, spawn_progress_ratio)
		else:
			printerr("Invalid child stats received in _on_bloon_spawn_children: ", child_stats)

#endregion Factory Functions


#region Bloon Stat Functions
# --- Bloon Stat Definition Functions ---

func _get_red_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED, 1, null, 0, false, false)
	stats.bloon_type = "Red"
	# stats.is_fortified = false (default)
	# stats.is_regrow = false (default)
	# stats.immunities = [] (default)
	# stats.moab_class = false (default)
	return stats

func _get_blue_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.4, 1, _get_red_stats(), 1, false, false)
	stats.bloon_type = "Blue"
	return stats

func _get_green_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.8, 1, _get_blue_stats(), 1, false, false)
	stats.bloon_type = "Green"
	return stats

func _get_yellow_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 3.2, 1, _get_green_stats(), 1, false, false)
	stats.bloon_type = "Yellow"
	return stats

func _get_pink_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 3.5, 1, _get_yellow_stats(), 1, false, false)
	stats.bloon_type = "Pink"
	return stats

func _get_black_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.8, 1, _get_pink_stats(), 2, false, false)
	stats.bloon_type = "Black"
	stats.immunities = ["Explosive"]
	return stats

func _get_white_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 2.0, 1, _get_pink_stats(), 2, false, false)
	stats.bloon_type = "White"
	stats.immunities = ["Ice"]
	return stats

func _get_lead_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.0, 1, _get_black_stats(), 2, false, true)
	stats.bloon_type = "Lead"
	stats.immunities = ["Sharp"]
	return stats

func _get_zebra_stats() -> BloonStats:
	# Children handled specially in bloon.gd handle_pop
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.8, 1, null, 0, false, false)
	stats.bloon_type = "Zebra"
	stats.immunities = ["Explosive", "Ice"]
	return stats

func _get_rainbow_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 2.2, 1, _get_zebra_stats(), 2, false, false)
	stats.bloon_type = "Rainbow"
	return stats

func _get_purple_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(1, BASE_RED_SPEED * 3.0, 1, _get_pink_stats(), 2, false, false)
	stats.bloon_type = "Purple"
	stats.immunities = ["Fire", "Plasma", "Energy"]
	return stats

func _get_ceramic_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(10, BASE_RED_SPEED * 2.5, 1, _get_rainbow_stats(), 2, false, false)
	stats.bloon_type = "Ceramic"
	return stats

func _get_moab_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(200, BASE_RED_SPEED * 1.0, 1, _get_ceramic_stats(), 4, false, false)
	stats.bloon_type = "MOAB"
	stats.moab_class = true
	return stats

func _get_bfb_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(700, BASE_RED_SPEED * 0.25, 1, _get_moab_stats(), 4, false, false)
	stats.bloon_type = "BFB"
	stats.moab_class = true
	return stats

func _get_zomg_stats() -> BloonStats:
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(4000, BASE_RED_SPEED * 0.18, 1, _get_bfb_stats(), 4, false, false)
	stats.bloon_type = "ZOMG"
	stats.moab_class = true
	return stats

func _get_ddt_stats() -> BloonStats:
	# Children need to be Camo Regrow Ceramics - handle this later if needed
	var child_stats = _get_camo_regrow_ceramic_stats() # Use dedicated function
	child_stats.is_camo = true
	child_stats.is_regrow = true # Note: This mutates the result of _get_ceramic_stats. Better to create fresh if needed elsewhere.
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(400, BASE_RED_SPEED * 2.75, 1, child_stats, 4, true, true)
	stats.bloon_type = "DDT"
	stats.immunities = ["Sharp", "Explosive"] # Lead + Black properties
	stats.moab_class = true
	return stats

func _get_bad_stats() -> BloonStats:
	# Children handled specially in bloon.gd handle_pop
	# health, speed, cash, child_stats, child_count, camo, lead
	var stats = BloonStats.new(20000, BASE_RED_SPEED * 0.18, 1, null, 0, false, false)
	stats.bloon_type = "BAD"
	stats.moab_class = true
	return stats

#region Modifiers

# --- Fortified Stat Functions ---
func _get_fortified_lead_stats() -> BloonStats:
	var stats = _get_lead_stats()
	stats.health = 2 # Fortified Lead has 2 health (vs 1)
	stats.is_fortified = true
	return stats

func _get_fortified_ceramic_stats() -> BloonStats:
	var stats = _get_ceramic_stats()
	stats.health *= 2 # Fortified Ceramic has 20 health (vs 10)
	stats.is_fortified = true
	return stats

func _get_fortified_purple_stats() -> BloonStats:
	var stats = _get_purple_stats()
	# Fortified Purple has 2 health? (Needs confirmation, assuming 1 layer still)
	stats.is_fortified = true
	return stats

func _get_fortified_moab_stats() -> BloonStats:
	var stats = _get_moab_stats()
	stats.health *= 2 # Fortified MOAB has 400 health (vs 200)
	stats.is_fortified = true
	# Children are standard Ceramics
	return stats

func _get_fortified_bfb_stats() -> BloonStats:
	var stats = _get_bfb_stats()
	stats.health *= 2 # Fortified BFB has 1400 health (vs 700)
	stats.is_fortified = true
	# Children are standard MOABs
	return stats

func _get_fortified_zomg_stats() -> BloonStats:
	var stats = _get_zomg_stats()
	stats.health *= 2 # Fortified ZOMG has 8000 health (vs 4000)
	stats.is_fortified = true
	# Children are standard BFBs
	return stats

func _get_fortified_ddt_stats() -> BloonStats:
	var stats = _get_ddt_stats()
	stats.health *= 2 # Fortified DDT has 800 health (vs 400)
	stats.is_fortified = true
	# Children are Camo Regrow Ceramics (already handled by _get_ddt_stats child)
	return stats

func _get_fortified_bad_stats() -> BloonStats:
	var stats = _get_bad_stats()
	stats.health *= 2 # Fortified BAD has 40000 health (vs 20000)
	stats.is_fortified = true
	# Children are standard ZOMGs and DDTs (handled by BAD pop logic)
	return stats

# --- Camo Stat Functions ---
func _get_camo_lead_stats() -> BloonStats:
	var stats = _get_lead_stats()
	stats.is_camo = true
	return stats

func _get_camo_purple_stats() -> BloonStats:
	var stats = _get_purple_stats()
	stats.is_camo = true
	return stats

func _get_camo_ceramic_stats() -> BloonStats:
	var stats = _get_ceramic_stats()
	stats.is_camo = true
	return stats

# --- NEW ---
func _get_camo_red_stats() -> BloonStats: var stats = _get_red_stats(); stats.is_camo = true; return stats
func _get_camo_blue_stats() -> BloonStats: var stats = _get_blue_stats(); stats.is_camo = true; return stats
func _get_camo_green_stats() -> BloonStats: var stats = _get_green_stats(); stats.is_camo = true; return stats
func _get_camo_yellow_stats() -> BloonStats: var stats = _get_yellow_stats(); stats.is_camo = true; return stats
func _get_camo_pink_stats() -> BloonStats: var stats = _get_pink_stats(); stats.is_camo = true; return stats
func _get_camo_black_stats() -> BloonStats: var stats = _get_black_stats(); stats.is_camo = true; return stats
func _get_camo_white_stats() -> BloonStats: var stats = _get_white_stats(); stats.is_camo = true; return stats
func _get_camo_zebra_stats() -> BloonStats: var stats = _get_zebra_stats(); stats.is_camo = true; return stats
func _get_camo_rainbow_stats() -> BloonStats: var stats = _get_rainbow_stats(); stats.is_camo = true; return stats

# --- Regrow Stat Functions ---
func _get_regrow_lead_stats() -> BloonStats:
	var stats = _get_lead_stats()
	stats.is_regrow = true
	return stats

# --- NEW ---
func _get_regrow_red_stats() -> BloonStats: var stats = _get_red_stats(); stats.is_regrow = true; return stats
func _get_regrow_blue_stats() -> BloonStats: var stats = _get_blue_stats(); stats.is_regrow = true; return stats
func _get_regrow_green_stats() -> BloonStats: var stats = _get_green_stats(); stats.is_regrow = true; return stats
func _get_regrow_yellow_stats() -> BloonStats: var stats = _get_yellow_stats(); stats.is_regrow = true; return stats
func _get_regrow_pink_stats() -> BloonStats: var stats = _get_pink_stats(); stats.is_regrow = true; return stats
func _get_regrow_black_stats() -> BloonStats: var stats = _get_black_stats(); stats.is_regrow = true; return stats
func _get_regrow_white_stats() -> BloonStats: var stats = _get_white_stats(); stats.is_regrow = true; return stats
func _get_regrow_zebra_stats() -> BloonStats: var stats = _get_zebra_stats(); stats.is_regrow = true; return stats
func _get_regrow_rainbow_stats() -> BloonStats: var stats = _get_rainbow_stats(); stats.is_regrow = true; return stats
func _get_regrow_purple_stats() -> BloonStats: var stats = _get_purple_stats(); stats.is_regrow = true; return stats
func _get_regrow_ceramic_stats() -> BloonStats: var stats = _get_ceramic_stats(); stats.is_regrow = true; return stats


# --- Combined Stat Functions ---
func _get_camo_regrow_lead_stats() -> BloonStats:
	var stats = _get_lead_stats()
	stats.is_camo = true
	stats.is_regrow = true
	return stats

func _get_fortified_camo_lead_stats() -> BloonStats:
	var stats = _get_fortified_lead_stats()
	stats.is_camo = true
	return stats

func _get_fortified_camo_ceramic_stats() -> BloonStats:
	var stats = _get_fortified_ceramic_stats()
	stats.is_camo = true
	return stats

func _get_fortified_camo_regrow_lead_stats() -> BloonStats:
	# Needed for r126
	var stats = _get_fortified_lead_stats()
	stats.is_camo = true
	stats.is_regrow = true
	return stats

func _get_camo_regrow_ceramic_stats() -> BloonStats:
	# Needed for DDT children
	var stats = _get_ceramic_stats()
	stats.is_camo = true
	stats.is_regrow = true
	return stats

# --- NEW ---
func _get_camo_regrow_red_stats() -> BloonStats: var stats = _get_red_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_blue_stats() -> BloonStats: var stats = _get_blue_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_green_stats() -> BloonStats: var stats = _get_green_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_yellow_stats() -> BloonStats: var stats = _get_yellow_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_pink_stats() -> BloonStats: var stats = _get_pink_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_black_stats() -> BloonStats: var stats = _get_black_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_white_stats() -> BloonStats: var stats = _get_white_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_zebra_stats() -> BloonStats: var stats = _get_zebra_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_rainbow_stats() -> BloonStats: var stats = _get_rainbow_stats(); stats.is_camo = true; stats.is_regrow = true; return stats
func _get_camo_regrow_purple_stats() -> BloonStats: var stats = _get_purple_stats(); stats.is_camo = true; stats.is_regrow = true; return stats

#endregion Modifiers
#endregion
