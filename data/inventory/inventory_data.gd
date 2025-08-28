# inventory_data.gd
class_name InventoryData
extends Resource

# Description
## A data container for all inventory properties.

@export var capacity: int = 20
@export var items: Array[ItemData] = []
