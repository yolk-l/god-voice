extends Action

var _going_home: bool = false

func get_action_name() -> String:
	return "rest"

func can_execute(villager: Villager, world: Node) -> bool:
	if villager.needs.stamina < 40.0:
		return true
	if (GameManager.is_night() or GameManager.is_dusk()) and villager.needs.stamina < 80.0:
		return true
	return false

func calculate_utility(villager: Villager, world: Node) -> float:
	var base: float = (1.0 - villager.needs.stamina / 100.0) * 0.8
	if GameManager.is_night():
		base += 0.3
	elif GameManager.is_dusk():
		base += 0.15
	var camp: Vector2 = BuildingManager.get_camp()
	var dist_from_camp: float = villager.global_position.distance_to(camp)
	if dist_from_camp > 160.0:
		base += 0.2
	return clampf(base, 0.0, 1.0)

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_going_home = false
	if villager.home and is_instance_valid(villager.home):
		villager.navigate_to(villager.home.global_position)
		_going_home = true
	else:
		var camp: Vector2 = BuildingManager.get_camp()
		if villager.global_position.distance_to(camp) > 32.0:
			villager.navigate_to(camp)
			_going_home = true
	villager.needs.set_working(false)

func tick(villager: Villager, world: Node, delta: float) -> void:
	if _going_home and not villager.has_reached_target():
		return
	_going_home = false
	var sheltered := villager.home != null and is_instance_valid(villager.home)
	if sheltered:
		sheltered = villager.global_position.distance_to(villager.home.global_position) < 20.0
	villager.needs.set_resting(true, sheltered)
	if villager.needs.stamina >= 80.0:
		villager.needs.set_resting(false)
		_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_resting(false)
	_completed = true
