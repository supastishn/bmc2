# File: res://stats/projectile_stats.gd
class_name ProjectileStats
extends Resource

## How fast the projectile travels (units per second).
@export var speed: float = 15.0
## How much damage the projectile deals on hit.
@export var damage: int = 1
## How long the projectile exists before disappearing (seconds).
@export var lifetime: float = 2.0
## Number of bloons this projectile can hit before disappearing.
@export var pierce: int = 1
## If true, this projectile can damage Lead bloons.
@export var can_pop_lead: bool = false
## If true, the projectile will attempt to track a target.
@export var homing_enabled: bool = false
## How quickly the projectile turns towards its target (radians/sec factor).
@export var homing_turn_rate: float = 5.0
## Visual representation of the projectile.
@export var mesh: Mesh # <<< ADDED
# --- NEW Properties ---
## Type of damage dealt (Sharp, Shatter, Normal, Plasma, Energy, Explosive etc.)
@export var damage_type: String = "Sharp"
## Chance to crit (0.0 to 1.0). Not used if crit_frequency > 0.
@export var crit_chance: float = 0.0
## Flat extra damage added on a critical hit.
@export var crit_extra_damage: int = 0
## Deals a critical hit every N shots (0 = disabled). Overrides crit_chance.
@export var crit_frequency: int = 0
## Internal counter used by tower/projectile logic if crit_frequency > 0.
@export var shot_counter_for_crit: int = 0 # Managed externally
## Extra damage dealt to Fortified bloons.
@export var extra_fortified_damage: int = 0
## Extra damage dealt to Ceramic bloons.
@export var extra_ceramic_damage: int = 0
## Extra damage dealt to Lead bloons.
@export var extra_lead_damage: int = 0
## If true, projectile can rebound off obstacles (requires physics layer setup).
@export var can_rebound: bool = false
## If true, projectile applies a knockback effect on hit.
@export var applies_knockback: bool = false
## Duration of the knockback effect in seconds.
@export var knockback_duration: float = 0.15
## Speed multiplier for Ceramic/Lead bloons hit by knockback (e.g., -1.0 for -100% speed).
@export var knockback_slow_ceramic_lead: float = -1.0
## Speed multiplier for other bloons hit by knockback (e.g., -5.0 for -500% speed).
@export var knockback_slow_other: float = -5.0
## If true, emits other projectiles when this one expires by lifetime/map border.
@export var emits_on_expire: bool = false
## If true, emits other projectiles when pierce reaches certain thresholds (e.g., 50%, 0).
@export var emits_on_pierce_loss: bool = false
## The scene of the projectile to emit.
@export var emitted_projectile_scene: PackedScene = null
## Number of projectiles to emit each time.
@export var emit_count: int = 0

# Constructor to allow programmatic initialization
func _init(p_speed: float = 15.0,
			p_damage: int = 1,
			p_lifetime: float = 2.0,
			p_pierce: int = 1,
			# p_can_pop_lead is derived from damage_type now
			p_homing_enabled: bool = false,
			p_homing_turn_rate: float = 5.0,
			p_mesh: Mesh = null, # <<< ADDED PARAM
			p_damage_type: String = "Sharp",
			p_crit_chance: float = 0.0,
			p_crit_extra_damage: int = 0,
			p_crit_frequency: int = 0,
			p_extra_fortified_damage: int = 0,
			p_extra_ceramic_damage: int = 0,
			p_extra_lead_damage: int = 0,
			p_can_rebound: bool = false,
			p_applies_knockback: bool = false,
			p_knockback_duration: float = 0.15,
			p_knockback_slow_ceramic_lead: float = -1.0,
			p_knockback_slow_other: float = -5.0,
			p_emits_on_expire: bool = false,
			p_emits_on_pierce_loss: bool = false,
			p_emitted_projectile_scene: PackedScene = null,
			p_emit_count: int = 0):
	speed = p_speed
	damage = p_damage
	lifetime = p_lifetime
	pierce = p_pierce
	can_pop_lead = not (p_damage_type in ["Sharp"]) # Example derivation
	homing_enabled = p_homing_enabled
	homing_turn_rate = p_homing_turn_rate
	mesh = p_mesh # <<< ADDED ASSIGNMENT
	damage_type = p_damage_type
	crit_chance = p_crit_chance
	crit_extra_damage = p_crit_extra_damage
	crit_frequency = p_crit_frequency
	extra_fortified_damage = p_extra_fortified_damage
	extra_ceramic_damage = p_extra_ceramic_damage
	extra_lead_damage = p_extra_lead_damage
	can_rebound = p_can_rebound
	applies_knockback = p_applies_knockback
	knockback_duration = p_knockback_duration
	knockback_slow_ceramic_lead = p_knockback_slow_ceramic_lead
	knockback_slow_other = p_knockback_slow_other
	emits_on_expire = p_emits_on_expire
	emits_on_pierce_loss = p_emits_on_pierce_loss
	emitted_projectile_scene = p_emitted_projectile_scene
	emit_count = p_emit_count
