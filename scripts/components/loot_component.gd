# scripts/components/loot_component.gd
# Handles the logic for dropping an item from a weighted loot table.
class_name LootComponent
extends Node

# Preload the scene we'll need to spawn.
const LootDropScene = preload("res://scenes/items/loot_drop.tscn")

@export var loot_table: LootTableData

# This function now delegates the complex logic to the loot table.
func drop_loot(position: Vector2) -> void:
	if not loot_table:
		return
		
	# Ask the loot table to do the calculation.
	var item_to_drop = loot_table.get_drop()

	# If we got an item, spawn it.
	if item_to_drop:
		# Spawn and initialize the loot drop scene.
		var loot_instance = LootDropScene.instantiate()
		# Set the loot drops position
		loot_instance.global_position = position
		
		# Get the current level from our reliable LevelManager service.
		var level = LevelManager.get_current_level()
		if not is_instance_valid(level): 
			return
		
		# THE FIX: Find the WorldYSort node instead of the old LootContainer.
		var loot_container = level.get_node_or_null("WorldYSort")
		
		if not loot_container:
			push_error("Could not find 'WorldYSort' node in the current level!")
			return
		
		# The LootSpawner will see this action and replicate it for all clients.
		loot_container.add_child(loot_instance, true) # Add 'true' to force a network-safe name.
		
		# Call our RPC to tell all clients to
		# set the position, item data, and make it visible.
		loot_instance.initialize.rpc(item_to_drop.resource_path, position)
