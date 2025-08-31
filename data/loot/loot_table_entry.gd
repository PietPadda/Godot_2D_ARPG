# file: data/loot/loot_table_entry.gd
# Defines a single entry in a loot table, pairing an item with its drop weight.
class_name LootTableEntry
extends Resource

# Description
## Defines a single entry in a loot table, pairing an item with its drop weight.

@export var item: ItemData
@export var weight: float = 1.0
