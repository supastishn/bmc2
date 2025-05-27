extends Node
class_name BloonFactory

const BASE_RED_SPEED = 2.0

# Map keys in waves.json → factory methods
const STAT_FUNC_MAP := {
	"red": get_red_stats,      "blue": get_blue_stats,
	"green": get_green_stats,  "yellow": get_yellow_stats,
	"pink": get_pink_stats,    "black": get_black_stats,
	"white": get_white_stats,  "lead": get_lead_stats,
	"zebra": get_zebra_stats,  "rainbow": get_rainbow_stats,
	"purple": get_purple_stats,  "ceramic": get_ceramic_stats,
	"moab": get_moab_stats,    "bfb": get_bfb_stats,
	"zomg": get_zomg_stats,    "ddt": get_ddt_stats,
	"bad": get_bad_stats,

	"fortified_lead":   get_fortified_lead_stats,
	"fortified_ceramic":get_fortified_ceramic_stats,
	"fortified_purple": get_fortified_purple_stats,
	"fortified_moab":   get_fortified_moab_stats,
	"fortified_bfb":    get_fortified_bfb_stats,
	"fortified_zomg":   get_fortified_zomg_stats,
	"fortified_ddt":    get_fortified_ddt_stats,
	"fortified_bad":    get_fortified_bad_stats,

	"camo_lead":    get_camo_lead_stats,
	"camo_purple":  get_camo_purple_stats,
	"camo_ceramic": get_camo_ceramic_stats,
	"camo_red":     get_camo_red_stats,
	"camo_blue":    get_camo_blue_stats,
	"camo_green":   get_camo_green_stats,
	"camo_yellow":  get_camo_yellow_stats,
	"camo_pink":    get_camo_pink_stats,
	"camo_black":   get_camo_black_stats,
	"camo_white":   get_camo_white_stats,
	"camo_zebra":   get_camo_zebra_stats,
	"camo_rainbow": get_camo_rainbow_stats,
	"camo_moab":    get_camo_moab_stats,
	"camo_bfb":     get_camo_bfb_stats,
	"camo_zomg":    get_camo_zomg_stats,

	"fortified_camo_lead":     get_fortified_camo_lead_stats,
	"fortified_camo_ceramic":  get_fortified_camo_ceramic_stats,
	"fortified_camo_moab":     get_fortified_camo_moab_stats,
	"fortified_camo_bfb":      get_fortified_camo_bfb_stats,
	"fortified_camo_zomg":     get_fortified_camo_zomg_stats,
}

static func get_red_stats() -> BloonStats:
	var stats = BloonStats.new(1, BASE_RED_SPEED, 1, null, 0, false, false)
	stats.bloon_type = "Red"
	return stats

static func get_blue_stats() -> BloonStats:
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.4, 1, get_red_stats(), 1, false, false)
	stats.bloon_type = "Blue"
	return stats

static func get_green_stats() -> BloonStats:
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.8, 1, get_blue_stats(), 1, false, false)
	stats.bloon_type = "Green"
	return stats

static func get_yellow_stats() -> BloonStats:
	var stats = BloonStats.new(1, BASE_RED_SPEED * 3.2, 1, get_green_stats(), 1, false, false)
	stats.bloon_type = "Yellow"
	return stats

static func get_pink_stats() -> BloonStats:
	var stats = BloonStats.new(1, BASE_RED_SPEED * 3.5, 1, get_yellow_stats(), 1, false, false)
	stats.bloon_type = "Pink"
	return stats

static func get_black_stats() -> BloonStats:
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.8, 1, get_pink_stats(), 2, false, false)
	stats.bloon_type = "Black"
	stats.immunities = ["Explosive"]
	return stats

static func get_white_stats() -> BloonStats:
	var stats = BloonStats.new(1, BASE_RED_SPEED * 2.0, 1, get_pink_stats(), 2, false, false)
	stats.bloon_type = "White"
	stats.immunities = ["Ice"]
	return stats

static func get_lead_stats() -> BloonStats:
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.0, 1, get_black_stats(), 2, false, true)
	stats.bloon_type = "Lead"
	stats.immunities = ["Sharp"]
	return stats

static func get_zebra_stats() -> BloonStats:
	var stats = BloonStats.new(1, BASE_RED_SPEED * 1.8, 1, null, 0, false, false)
	stats.bloon_type = "Zebra"
	stats.immunities = ["Explosive", "Ice"]
	return stats

static func get_rainbow_stats() -> BloonStats:
	var stats = BloonStats.new(1, BASE_RED_SPEED * 2.2, 1, get_zebra_stats(), 2, false, false)
	stats.bloon_type = "Rainbow"
	return stats

static func get_purple_stats() -> BloonStats:
	var stats = BloonStats.new(1, BASE_RED_SPEED * 3.0, 1, get_pink_stats(), 2, false, false)
	stats.bloon_type = "Purple"
	stats.immunities = ["Fire", "Plasma", "Energy"]
	return stats

static func get_ceramic_stats() -> BloonStats:
	var stats = BloonStats.new(10, BASE_RED_SPEED * 2.5, 1, get_rainbow_stats(), 2, false, false)
	stats.bloon_type = "Ceramic"
	return stats

static func get_moab_stats() -> BloonStats:
	var stats = BloonStats.new(200, BASE_RED_SPEED * 1.0, 1, get_ceramic_stats(), 4, false, false)
	stats.bloon_type = "MOAB"
	stats.moab_class = true
	return stats

static func get_bfb_stats() -> BloonStats:
	var stats = BloonStats.new(700, BASE_RED_SPEED * 0.25, 1, get_moab_stats(), 4, false, false)
	stats.bloon_type = "BFB"
	stats.moab_class = true
	return stats

static func get_zomg_stats() -> BloonStats:
	var stats = BloonStats.new(4000, BASE_RED_SPEED * 0.18, 1, get_bfb_stats(), 4, false, false)
	stats.bloon_type = "ZOMG"
	stats.moab_class = true
	return stats

static func get_ddt_stats() -> BloonStats:
	var child_stats = get_camo_regrow_ceramic_stats()
	child_stats.is_camo = true
	child_stats.is_regrow = true
	var stats = BloonStats.new(400, BASE_RED_SPEED * 2.75, 1, child_stats, 4, true, true)
	stats.bloon_type = "DDT"
	stats.immunities = ["Sharp", "Explosive"]
	stats.moab_class = true
	return stats

static func get_bad_stats() -> BloonStats:
	var stats = BloonStats.new(20000, BASE_RED_SPEED * 0.18, 1, null, 0, false, false)
	stats.bloon_type = "BAD"
	stats.moab_class = true
	return stats

static func get_fortified_lead_stats() -> BloonStats:
	var stats = get_lead_stats()
	stats.health = 2
	stats.is_fortified = true
	return stats

static func get_fortified_ceramic_stats() -> BloonStats:
	var stats = get_ceramic_stats()
	stats.health *= 2
	stats.is_fortified = true
	return stats

static func get_fortified_purple_stats() -> BloonStats:
	var stats = get_purple_stats()
	stats.is_fortified = true
	return stats

static func get_fortified_moab_stats() -> BloonStats:
	var stats = get_moab_stats()
	stats.health *= 2
	stats.is_fortified = true
	return stats

static func get_fortified_bfb_stats() -> BloonStats:
	var stats = get_bfb_stats()
	stats.health *= 2
	stats.is_fortified = true
	return stats

static func get_fortified_zomg_stats() -> BloonStats:
	var stats = get_zomg_stats()
	stats.health *= 2
	stats.is_fortified = true
	return stats

static func get_fortified_ddt_stats() -> BloonStats:
	var stats = get_ddt_stats()
	stats.health *= 2
	stats.is_fortified = true
	return stats

static func get_fortified_bad_stats() -> BloonStats:
	var stats = get_bad_stats()
	stats.health *= 2
	stats.is_fortified = true
	return stats

static func get_camo_lead_stats() -> BloonStats:
	var stats = get_lead_stats()
	stats.is_camo = true
	return stats

static func get_camo_purple_stats() -> BloonStats:
	var stats = get_purple_stats()
	stats.is_camo = true
	return stats

static func get_camo_ceramic_stats() -> BloonStats:
	var stats = get_ceramic_stats()
	stats.is_camo = true
	return stats

static func get_camo_red_stats() -> BloonStats: var stats = get_red_stats(); stats.is_camo = true; return stats
static func get_camo_blue_stats() -> BloonStats: var stats = get_blue_stats(); stats.is_camo = true; return stats
static func get_camo_green_stats() -> BloonStats: var stats = get_green_stats(); stats.is_camo = true; return stats
static func get_camo_yellow_stats() -> BloonStats: var stats = get_yellow_stats(); stats.is_camo = true; return stats
static func get_camo_pink_stats() -> BloonStats: var stats = get_pink_stats(); stats.is_camo = true; return stats
static func get_camo_black_stats() -> BloonStats: var stats = get_black_stats(); stats.is_camo = true; return stats
static func get_camo_white_stats() -> BloonStats: var stats = get_white_stats(); stats.is_camo = true; return stats
static func get_camo_zebra_stats() -> BloonStats: var stats = get_zebra_stats(); stats.is_camo = true; return stats
static func get_camo_rainbow_stats() -> BloonStats: var stats = get_rainbow_stats(); stats.is_camo = true; return stats

static func get_camo_moab_stats() -> BloonStats:
	var s = get_moab_stats()
	s.is_camo = true
	return s

static func get_camo_bfb_stats() -> BloonStats:
	var s = get_bfb_stats()
	s.is_camo = true
	return s

static func get_camo_zomg_stats() -> BloonStats:
	var s = get_zomg_stats()
	s.is_camo = true
	return s

static func get_fortified_camo_lead_stats() -> BloonStats:
	var stats = get_fortified_lead_stats()
	stats.is_camo = true
	return stats

static func get_fortified_camo_ceramic_stats() -> BloonStats:
	var stats = get_fortified_ceramic_stats()
	stats.is_camo = true
	return stats

static func get_fortified_camo_moab_stats() -> BloonStats:
	var s = get_fortified_moab_stats()
	s.is_camo = true
	return s

static func get_fortified_camo_bfb_stats() -> BloonStats:
	var s = get_fortified_bfb_stats()
	s.is_camo = true
	return s

static func get_fortified_camo_zomg_stats() -> BloonStats:
	var s = get_fortified_zomg_stats()
	s.is_camo = true
	return s

static func get_camo_regrow_ceramic_stats() -> BloonStats:
	var stats = get_ceramic_stats()
	stats.is_camo = true
	stats.is_regrow = true
	return stats
