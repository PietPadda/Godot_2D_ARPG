# inventory_component.gd
class_name InventoryComponent
extends Node

@export var inventory_data: InventoryData

# Tries to add an item to the inventory. Returns true on success.
func add_item(item_data: ItemData) -> bool:
	if inventory_data.items.size() < inventory_data.capacity:
		inventory_data.items.append(item_data)
		print("Item added: ", item_data.item_name)
		print("Inventory now contains: ", inventory_data.items)
		return true
	else:
		print("Inventory is full!")
		return false
