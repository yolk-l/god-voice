extends Action

var _target_pos: Vector2 = Vector2.ZERO
var _explore_timer: float = 0.0
const MAX_EXPLORE_TIME := 8.0
const MAX_EXPLORE_RANGE := 10.0

func get_action_name() -> String:
	return "explore"

func can_execute(villager: Villager, world: Node) -> bool:
	return true

func calculate_utility(villager: Villager, world: Node) -> float:
	var camp: Vector2 = BuildingManager.get_camp()
	var camp_tile: Vector2i = Vector2i(camp / 16.0)
	var unexplored_near_camp := 0
	for dx in range(-8, 9):
		for dy in range(-8, 9):
			var check: Vector2i = camp_tile + Vector2i(dx, dy)
			if not villager.known_area.has(check):
				unexplored_near_camp += 1

	var nearby_food: Node = ResourceManager.find_nearest_in_area(
		camp, "food", 200.0, villager.known_area, false
	)
	var resource_scarce_bonus := 0.15 if nearby_food == null else 0.0

	var base: float = 0.1 + clampf(unexplored_near_camp / 100.0, 0.0, 0.25) + resource_scarce_bonus
	var dist_from_camp: float = villager.global_position.distance_to(camp)
	if dist_from_camp > 160.0:
		base -= 0.2
	return clampf(base, 0.0, 0.5)

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_explore_timer = 0.0
	_target_pos = _find_explore_target(villager, world)
	villager.navigate_to(_target_pos)

func tick(villager: Villager, world: Node, delta: float) -> void:
	_explore_timer += delta
	if villager.has_reached_target() or _explore_timer >= MAX_EXPLORE_TIME:
		_completed = true

func cancel(villager: Villager, world: Node) -> void:
	_completed = true

func _find_explore_target(villager: Villager, world: Node) -> Vector2:
	var camp: Vector2 = BuildingManager.get_camp()
	var camp_tile: Vector2i = Vector2i(camp / 16.0)
	var best_pos := Vector2.ZERO
	var best_unexplored := 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for _attempt in range(8):
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(4.0, MAX_EXPLORE_RANGE)
		var target_tile: Vector2i = camp_tile + Vector2i(int(cos(angle) * dist), int(sin(angle) * dist))
		target_tile.x = clampi(target_tile.x, 2, 117)
		target_tile.y = clampi(target_tile.y, 2, 117)

		if not world.is_tile_walkable(target_tile):
			continue

		var unexplored_count := 0
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var check: Vector2i = target_tile + Vector2i(dx, dy)
				if not villager.known_area.has(check):
					unexplored_count += 1

		if unexplored_count > best_unexplored:
			best_unexplored = unexplored_count
			best_pos = Vector2(target_tile) * 16.0 + Vector2(8, 8)

	if best_pos == Vector2.ZERO:
		var angle := rng.randf() * TAU
		best_pos = camp + Vector2(cos(angle), sin(angle)) * 80.0

	return best_pos
