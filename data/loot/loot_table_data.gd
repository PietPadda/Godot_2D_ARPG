# data/loot/loot_table_data.gd
# A data container for defining a set of possible item drops and their weights.
class_name LootTableData
extends Resource

# Description
## A data container for defining a set of possible item drops and their weights.

# This array will now correctly export a list of our unique LootTableEntry resources.
@export var drops: Array[LootTableEntry] = []

# This function now contains the weighted drop logic.
func get_drop() -> ItemData:
	if drops.is_empty():
		return null

	var total_weight: float = 0.0
	for drop in drops:
		total_weight += drop.weight

	var random_roll = randf_range(0, total_weight)
	var cumulative_weight: float = 0.0
	
	for drop in drops:
		cumulative_weight += drop.weight
		if random_roll <= cumulative_weight:
			# The data resource is now responsible for validating its own entries.
			if not is_instance_valid(drop.item) or drop.item.resource_path.is_empty():
				push_warning("Item in loot table is invalid or not saved!")
				return null # Return nothing if the chosen item is bad.
			
			return drop.item # Return the valid item.
	
	return null # Should only happen in an edge case, like if all weights are zero.
