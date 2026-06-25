extends PanelContainer

@onready var name_label: Label = $VBox/NameLabel
@onready var action_label: Label = $VBox/ActionLabel
@onready var hunger_bar: ProgressBar = $VBox/HungerBar
@onready var stamina_bar: ProgressBar = $VBox/StaminaBar
@onready var health_bar: ProgressBar = $VBox/HealthBar
@onready var inventory_label: Label = $VBox/InventoryLabel
@onready var equipment_label: Label = $VBox/EquipmentLabel

var _target_villager: Villager = null

func _ready() -> void:
	visible = false

func show_villager(villager: Villager) -> void:
	_target_villager = villager
	visible = true

func hide_panel() -> void:
	_target_villager = null
	visible = false

func _process(_delta: float) -> void:
	if not visible or _target_villager == null:
		return
	if not is_instance_valid(_target_villager):
		hide_panel()
		return
	_update_display()

func _update_display() -> void:
	var v: Villager = _target_villager
	name_label.text = v.villager_name
	action_label.text = v.current_action_name

	hunger_bar.value = v.needs.hunger
	hunger_bar.modulate = Color.RED if v.needs.hunger > 60 else Color.WHITE

	stamina_bar.value = v.needs.stamina
	stamina_bar.modulate = Color.YELLOW if v.needs.stamina < 30 else Color.WHITE

	health_bar.value = v.needs.health
	health_bar.modulate = Color.RED if v.needs.health < 50 else Color.WHITE

	var items: Dictionary = v.inventory.get_all_items()
	var text := ""
	for type in items:
		if text != "":
			text += ", "
		text += "%s:%d" % [type, items[type]]
	inventory_label.text = text if text != "" else "(empty)"

	var tool_name: String = v.get_equipped("tool")
	if tool_name != "":
		equipment_label.text = "Tool: %s" % _display_tool_name(tool_name)
	else:
		equipment_label.text = "Tool: --"

func _display_tool_name(type: String) -> String:
	match type:
		"stone_axe": return "Stone Axe"
		"stone_pickaxe": return "Stone Pickaxe"
		_: return type
