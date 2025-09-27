extends Node

# Lightweight loader for tower JSON definitions in res://data/towers/{name}.json
# Supports simple mod syntax on stats:
# - Numbers: 5 (set), "+1" (add), "*1.2" (multiply)
# - Booleans/strings: set directly

static func load_tower_json(tower_name: String) -> Dictionary:
	var path = "res://data/towers/%s.json" % tower_name
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	var data := JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data

static func _apply_number_op(current: float, op_val) -> float:
	if typeof(op_val) == TYPE_FLOAT or typeof(op_val) == TYPE_INT:
		return float(op_val)
	if typeof(op_val) == TYPE_STRING:
		var s: String = op_val
		if s.begins_with("+"):
			return current + float(s.substr(1))
		elif s.begins_with("*"):
			return current * float(s.substr(1))
		else:
			return float(s)
	return current

static func apply_mods(ts, ps, mods: Dictionary) -> void:
	# Tower fields
	if mods.has("tower"):
		var tmods: Dictionary = mods.tower
		if tmods.has("attack_cooldown"): ts.attack_cooldown = _apply_number_op(ts.attack_cooldown, tmods.attack_cooldown)
		if tmods.has("range"): ts.range = _apply_number_op(ts.range, tmods.range)
		if tmods.has("can_see_camo"): ts.can_see_camo = bool(tmods.can_see_camo)
		if tmods.has("projectiles_per_shot"): ts.projectiles_per_shot = int(_apply_number_op(ts.projectiles_per_shot, tmods.projectiles_per_shot))
		if tmods.has("spread_angle"): ts.spread_angle = _apply_number_op(ts.spread_angle, tmods.spread_angle)

	# Projectile fields
	if mods.has("projectile"):
		var pmods: Dictionary = mods.projectile
		if pmods.has("speed"): ps.speed = _apply_number_op(ps.speed, pmods.speed)
		if pmods.has("damage"): ps.damage = int(_apply_number_op(ps.damage, pmods.damage))
		if pmods.has("lifetime"): ps.lifetime = _apply_number_op(ps.lifetime, pmods.lifetime)
		if pmods.has("pierce"): ps.pierce = int(_apply_number_op(ps.pierce, pmods.pierce))
		if pmods.has("damage_type"): ps.damage_type = str(pmods.damage_type)
		# Derived flag for lead popping
		ps.can_pop_lead = not (ps.damage_type == "Sharp")
		if pmods.has("crit_frequency"): ps.crit_frequency = int(_apply_number_op(ps.crit_frequency, pmods.crit_frequency))
		if pmods.has("crit_extra_damage"): ps.crit_extra_damage = int(_apply_number_op(ps.crit_extra_damage, pmods.crit_extra_damage))
		if pmods.has("can_rebound"): ps.can_rebound = bool(pmods.can_rebound)
		if pmods.has("applies_knockback"): ps.applies_knockback = bool(pmods.applies_knockback)
		if pmods.has("extra_fortified_damage"): ps.extra_fortified_damage = int(_apply_number_op(ps.extra_fortified_damage, pmods.extra_fortified_damage))
		if pmods.has("extra_ceramic_damage"): ps.extra_ceramic_damage = int(_apply_number_op(ps.extra_ceramic_damage, pmods.extra_ceramic_damage))
		if pmods.has("extra_lead_damage"): ps.extra_lead_damage = int(_apply_number_op(ps.extra_lead_damage, pmods.extra_lead_damage))

