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
			
			# Spawn and initialize the loot drop scene.
			var loot_instance = LootDropScene.instantiate()
			# Initialize with data first (this is safe now because we use _ready in loot_drop.gd)
			loot_instance.initialize(item_to_drop)
			loot_instance.global_position = position
			
			# Find the LootContainer and add the fully-prepared child to it.
			# The LootSpawner will see this action and replicate it for all clients.
			var loot_container = get_tree().get_root().get_node("Main/LootContainer")
			if loot_container:
				loot_container.add_child(loot_instance)
			return # We found our drop, so exit the function.
