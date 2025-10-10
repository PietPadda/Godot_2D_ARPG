# scripts/components/loot_component.gd
# Handles the logic for dropping an item from a weighted loot table.
class_name LootComponent
extends Node

# Preload the scene we'll need to spawn.
const LootDropScene = preload("res://scenes/items/loot_drop.tscn")

@export var loot_table: LootTableData
