# data/loot/loot_table_data.gd
# A data container for defining a set of possible item drops and their weights.
class_name LootTableData
extends Resource

# Description
## A data container for defining a set of possible item drops and their weights.

# This array will now correctly export a list of our unique LootTableEntry resources.
@export var drops: Array[LootTableEntry] = []
