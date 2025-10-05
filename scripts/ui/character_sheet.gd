# scripts/ui/character_sheet.gd
class_name CharacterSheet
extends PanelContainer

# --- Scene Nodes ---
@onready var level_label: Label = %LevelLabel
@onready var xp_label: Label = %XPLabel
@onready var health_label: Label = %HealthLabel
@onready var mana_label: Label = %ManaLabel
@onready var gold_label: Label = %GoldLabel
@onready var damage_label: Label = %DamageLabel

# --- Properties ---
var stats_component: StatsComponent
var stat_calculator: StatCalculator

# This function will be called by the HUD to provide the necessary player components.
func initialize(stats_comp: StatsComponent, calculator: StatCalculator):
	self.stats_component = stats_comp
	self.stat_calculator = calculator

	# Connect to the signals from the StatsComponent to keep our UI live.
	stats_component.health_changed.connect(_on_health_changed)
	stats_component.mana_changed.connect(_on_mana_changed)
	stats_component.xp_changed.connect(_on_xp_changed)
	stats_component.gold_changed.connect(_on_gold_changed)
	
	# We can also connect to the equipment_changed signal to update stats like damage.
	var player = stats_component.get_owner()
	var equipment_component = player.get_node_or_null("EquipmentComponent")
	if is_instance_valid(equipment_component):
		equipment_component.equipment_changed.connect(redraw)

func _ready() -> void:
	pass

# This function will be called by the HUD to update all the stat labels.
func redraw() -> void:
	# Guard clause: Don't try to draw if we haven't been initialized yet.
	if not is_instance_valid(stats_component) or not is_instance_valid(stat_calculator):
		return
	
	# Manually trigger all update functions to populate the UI.
	_on_health_changed(stats_component.current_health, stats_component.total_max_health)
	_on_mana_changed(stats_component.current_mana, stats_component.total_max_mana)
	_on_xp_changed(stats_component.stats_data.level, stats_component.stats_data.current_xp, stats_component.stats_data.xp_to_next_level)
	_on_gold_changed(stats_component.stats_data.gold)
	
	# Update calculated stats like damage.
	var total_damage = stat_calculator.get_total_stat(Stats.STAT_NAMES[Stats.STAT.DAMAGE])
	damage_label.text = str(total_damage)
	
# --- Signal Handlers ---
func _on_health_changed(current: int, max_val: int):
	# Guard Clause: Don't run if @onready vars aren't populated yet.
	if not is_node_ready(): return
	health_label.text = "%d / %d" % [current, max_val]

func _on_mana_changed(current: int, max_val: int):
	# Guard Clause: Don't run if @onready vars aren't populated yet.
	if not is_node_ready(): return
	mana_label.text = "%d / %d" % [current, max_val]

func _on_xp_changed(level: int, current_xp: int, xp_to_next: int):
	# Guard Clause: Don't run if @onready vars aren't populated yet.
	if not is_node_ready(): return
	level_label.text = str(level)
	xp_label.text = "%d / %d" % [current_xp, xp_to_next]

func _on_gold_changed(total_gold: int):
	# Guard Clause: Don't run if @onready vars aren't populated yet.
	if not is_node_ready(): return
	gold_label.text = str(total_gold)
