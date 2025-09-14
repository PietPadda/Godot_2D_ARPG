# scripts/components/loot_component.gd
# Handles the logic for dropping an item from a weighted loot table.
class_name LootComponent
extends Node

# Preload the scene we'll need to spawn.
const LootDropScene = preload("res://scenes/items/loot_drop.tscn")

@export var loot_table: LootTableData

# This function performs the weighted random drop.
func drop_loot(position: Vector2) -> void:
	if not loot_table or loot_table.drops.is_empty():
		return # No loot to drop.

	var total_weight: float = 0.0 # init add 0
	for drop in loot_table.drops:
		total_weight += drop.weight # calc total table for dice rool

	var random_roll = randf_range(0, total_weight) # choose random number
	var cumulative_weight: float = 0.0 # init at 0
	
	# Do the loot drop calc
	for drop in loot_table.drops:
		cumulative_weight += drop.weight # each drop adds to cum weight (to find it's dartboard zone)
		if random_roll <= cumulative_weight: # if the roll is above the first, or next item, we go back and try again
			var item_to_drop = drop.item
			
			# Edge case handling
			if not is_instance_valid(item_to_drop) or item_to_drop.resource_path.is_empty():
				push_warning("Item in loot table is invalid or not saved!")
				return
			
			# Spawn and initialize the loot drop scene.
			var loot_instance = LootDropScene.instantiate()
			# Set the loot drops position
			loot_instance.global_position = position
			
			# Add the "blank" loot drop to the scene for everyone first.
			var loot_container = get_tree().get_root().get_node("Main/LootContainer")
			
			# The LootSpawner will see this action and replicate it for all clients.
			if loot_container:
				# Add 'true' to force a network-safe name.
				loot_container.add_child(loot_instance, true)
				
				# Call our new, unified RPC to tell all clients to
				# set the position, item data, and make it visible.
				loot_instance.initialize.rpc(item_to_drop.resource_path, position)
			return # We found our drop, so exit the function.
