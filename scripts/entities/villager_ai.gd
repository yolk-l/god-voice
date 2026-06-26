extends Node

var _utility_ai: UtilityAI
var _villager: Villager
var _world: Node
var _first_eval: bool = true
var _eval_count: int = 0

func _ready() -> void:
	_villager = get_parent() as Villager
	_world = get_tree().current_scene.get_node("World")
	_villager._ai = self

	_utility_ai = UtilityAI.new()
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_eat.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_gather_food.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_gather_mat.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_rest.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_explore.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_build.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_craft.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_deposit.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_pickup.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_research.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_cook.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_farm.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_smelt.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_weave.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_idle.gd").new())

	$DecisionTimer.timeout.connect(_on_decision_timer)
	print("[AI] VillagerAI loaded for %s with %d actions" % [_villager.villager_name, _utility_ai.actions.size()])

func _process(delta: float) -> void:
	if GameManager.game_speed == 0.0:
		return
	if _utility_ai.current_action:
		_utility_ai.current_action.tick(_villager, _world, delta * GameManager.game_speed)
		if _utility_ai.current_action.is_completed():
			_utility_ai.current_action = null
			_try_auto_deposit()
			_evaluate()

func _on_decision_timer() -> void:
	_evaluate()

func _evaluate() -> void:
	_eval_count += 1
	var best_action = _utility_ai.select_action(_villager, _world)
	if _first_eval or _eval_count % 40 == 0:
		var scores: Dictionary = _utility_ai.get_all_scores(_villager, _world)
		var inv: Dictionary = _villager.inventory.get_all_items()
		var top: Array = []
		for key in scores:
			if scores[key] > 0.01:
				top.append("%s:%.2f" % [key, scores[key]])
		print("[AI] %s eval#%d inv:%s scores:{%s}" % [_villager.villager_name, _eval_count, inv, ", ".join(top)])
		if _first_eval:
			_first_eval = false
	if best_action == null:
		return
	if best_action != _utility_ai.current_action:
		var old_name: String = _utility_ai.current_action.get_action_name() if _utility_ai.current_action else "none"
		var new_name: String = best_action.get_action_name()
		print("[AI] %s: %s -> %s" % [_villager.villager_name, old_name, new_name])
		if _utility_ai.current_action:
			_utility_ai.current_action.cancel(_villager, _world)
			_try_auto_deposit()
		_utility_ai.current_action = best_action
		best_action.start(_villager, _world)
		_villager.current_action_name = best_action.get_action_name()

func force_reevaluate() -> void:
	_evaluate()

func _try_auto_deposit() -> void:
	var chest: Node = BuildingManager.get_nearest_chest_with_space(_villager.global_position)
	if not chest:
		return
	var items: Dictionary = _villager.inventory.get_all_items()
	for type in items:
		if type in ["stone_axe", "stone_pickaxe"]:
			continue
		var amount: int = items[type]
		var deposited: int = chest.add_item(type, amount)
		_villager.inventory.remove_item(type, deposited)

func get_scores() -> Dictionary:
	return _utility_ai.get_all_scores(_villager, _world)
