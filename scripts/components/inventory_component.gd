# inventory_component.gd
class_name InventoryComponent
extends Node

# signals
signal inventory_changed # just a signal, no stale data pass

# scene nodes
@export var inventory_data: InventoryData

# Tries to add an item to the inventory. Returns true on success.
## add an item to the inventory
func add_item(item_data: ItemData) -> bool:
	if inventory_data.items.size() < inventory_data.capacity:
		inventory_data.items.append(item_data)
		emit_signal("inventory_changed") # Emit without data
		return true
	else:
		print("Inventory is full!")
		return false

## remove an item to the inventory
func remove_item(item_to_remove: ItemData) -> void:
	var item_index = inventory_data.items.find(item_to_remove)
	if item_index != -1:
		inventory_data.items.remove_at(item_index)
		emit_signal("inventory_changed") # Emit without data

# --- RPCs ---
## request add item to inv
@rpc("any_peer", "call_local", "reliable")
func client_add_item(item_path: String):
	var item_data = load(item_path) as ItemData
	if is_instance_valid(item_data):
		add_item(item_data)
