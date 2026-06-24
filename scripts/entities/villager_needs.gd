class_name VillagerNeeds
extends RefCounted

signal villager_died

var hunger: float = 0.0
var stamina: float = 100.0
var health: float = 100.0

const HUNGER_RATE := 8.0  # per game minute
const HUNGER_RATE_WORKING := 12.0
const STAMINA_DRAIN := 5.0  # per game minute
const STAMINA_DRAIN_GATHER := 10.0
const STAMINA_RECOVERY := 20.0
const STAMINA_RECOVERY_SHELTERED := 40.0
const HUNGER_DAMAGE_THRESHOLD := 80.0
const HUNGER_DAMAGE_RATE := 5.0  # health per game minute

var _is_working: bool = false
var _is_resting: bool = false
var _is_sheltered: bool = false

func set_working(working: bool) -> void:
	_is_working = working

func set_resting(resting: bool, sheltered: bool = false) -> void:
	_is_resting = resting
	_is_sheltered = sheltered

func update(delta: float, game_speed: float) -> void:
	if game_speed == 0.0:
		return
	var game_minutes := delta * game_speed / 60.0

	# Hunger
	var hunger_rate := HUNGER_RATE_WORKING if _is_working else HUNGER_RATE
	hunger = clampf(hunger + hunger_rate * game_minutes, 0.0, 100.0)

	# Stamina
	if _is_resting:
		var recovery := STAMINA_RECOVERY_SHELTERED if _is_sheltered else STAMINA_RECOVERY
		if GameManager.is_night() and not _is_sheltered:
			recovery *= 0.5
		stamina = clampf(stamina + recovery * game_minutes, 0.0, 100.0)
	else:
		var drain := STAMINA_DRAIN_GATHER if _is_working else STAMINA_DRAIN
		stamina = clampf(stamina - drain * game_minutes, 0.0, 100.0)

	# Health damage from starvation
	if hunger >= HUNGER_DAMAGE_THRESHOLD:
		health = clampf(health - HUNGER_DAMAGE_RATE * game_minutes, 0.0, 100.0)

	if health <= 0.0:
		villager_died.emit()

func eat(nutrition: float) -> void:
	hunger = clampf(hunger - nutrition, 0.0, 100.0)

func heal(amount: float) -> void:
	health = clampf(health + amount, 0.0, 100.0)

func get_hunger_urgency() -> float:
	return hunger / 100.0

func get_rest_urgency() -> float:
	return 1.0 - stamina / 100.0

func get_health_urgency() -> float:
	if health > 50.0:
		return 0.0
	return 1.0 - health / 100.0

func is_exhausted() -> bool:
	return stamina <= 0.0

func get_move_speed_multiplier() -> float:
	var mult := 1.0
	if stamina <= 0.0:
		mult *= 0.5
	if GameManager.is_night():
		mult *= 0.8
	return mult
