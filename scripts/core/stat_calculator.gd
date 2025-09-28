# scripts/core/stat_calculator.gd
# A reusable service that calculates an entity's final stats from its components.
class_name StatCalculator
extends Node

# --- Dependencies ---
# We inject all the components that can provide stat data.
@export var stats_component: StatsComponent
@export var attack_component: AttackComponent
@export var equipment_component: EquipmentComponent
# In the future, we could easily add: @export var buff_component: BuffComponent

# --- Public API ---
# This is the single source of truth for all stat calculations in the game.
func get_total_stat(stat_name: String) -> float:
	var total_value: float = 0.0
	
	# Get the base value from the Attack or Stats component.
	if (stat_name == Stats.STAT_NAMES[Stats.STAT.DAMAGE] or stat_name == Stats.STAT_NAMES[Stats.STAT.RANGE]) and attack_component and attack_component.attack_data:
		total_value = attack_component.attack_data.get(stat_name)
	elif stats_component and stats_component.stats_data and stat_name in stats_component.stats_data:
		total_value = stats_component.stats_data.get(stat_name)
		
	# Add modifiers from equipment.
	# It's safe to check for the component, as enemies won't have one.
	# Add modifiers from equipment by looping through the new array.
	if equipment_component and equipment_component.equipment_data:
		for item in equipment_component.equipment_data.equipped_items.values():
			if item:
				# Loop through each StatModifier resource in the item's array.
				for modifier in item.stat_modifiers:
					# Check if the modifier's enum matches the one we're looking for.
					# Convert the modifier's enum (int) to its string name before comparing.
					if Stats.STAT_NAMES[modifier.stat] == stat_name:
						total_value += modifier.value
	
	# In the future, we could add buffs here:
	# if buff_component:
	#     total_value = buff_component.apply_buffs(stat_name, total_value)
		
	return total_value
