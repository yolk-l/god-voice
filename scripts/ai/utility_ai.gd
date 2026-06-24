class_name UtilityAI
extends RefCounted

var actions: Array = []  # Array of Action
var current_action = null
var inertia_bonus: float = 0.1

func register_action(action) -> void:
	actions.append(action)

func select_action(villager: Villager, world: Node) -> Variant:
	var best_action = null
	var best_score: float = 0.0

	for action in actions:
		if not action.can_execute(villager, world):
			continue
		var score: float = action.calculate_utility(villager, world)
		if action == current_action and current_action != null and not current_action.is_completed():
			score += inertia_bonus
		score = clampf(score, 0.0, 1.0)
		if score > best_score:
			best_score = score
			best_action = action

	return best_action

func get_all_scores(villager: Villager, world: Node) -> Dictionary:
	var scores: Dictionary = {}
	for action in actions:
		var score: float = 0.0
		if action.can_execute(villager, world):
			score = action.calculate_utility(villager, world)
			if action == current_action and current_action != null and not current_action.is_completed():
				score += inertia_bonus
			score = clampf(score, 0.0, 1.0)
		scores[action.get_action_name()] = score
	return scores
