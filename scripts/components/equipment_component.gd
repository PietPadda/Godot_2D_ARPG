# equipment_component.gd
class_name EquipmentComponent
extends Node

# Event driven signals
signal equipment_changed

# expose for resource field
@export var equipment_data: EquipmentData

# Equips an item into its designated slot.
func equip_item(item: ItemData) -> void:
	if item.equipment_slot != ItemData.EquipmentSlot.NONE: # if it's equippable
		# Perform the logic locally first for immediate feedback.
		equipment_data.equipped_items[item.equipment_slot] = item # equip in slot
		emit_signal("equipment_changed") # event signal
		
		# If we are the client in control, tell the server what we just did.
		if get_owner().is_multiplayer_authority():
			server_equip_item.rpc_id(1, item.resource_path, item.equipment_slot)

# Unequips an item from a specific slot.
func unequip_item_by_slot(slot: ItemData.EquipmentSlot) -> void:
	if equipment_data.equipped_items.has(slot) and equipment_data.equipped_items[slot] != null:
		# Perform the logic locally first.
		equipment_data.equipped_items[slot] = null
		emit_signal("equipment_changed") # Announce the change
		
		# If we are the client in control, tell the server.
		if get_owner().is_multiplayer_authority():
			server_unequip_item.rpc_id(1, slot)

# --- RPCs ---
# Runs on the server when a client requests to equip an item.
@rpc("any_peer", "call_local", "reliable")
func server_equip_item(item_path: String, slot: ItemData.EquipmentSlot):
	var item_resource = ItemDatabase.get_item(item_path)
	if is_instance_valid(item_resource):
		equipment_data.equipped_items[slot] = item_resource
		emit_signal("equipment_changed") # This triggers stat recalculation on the server's puppet.

# Runs on the server when a client requests to unequip an item.
@rpc("any_peer", "call_local", "reliable")
func server_unequip_item(slot: ItemData.EquipmentSlot):
	if equipment_data.equipped_items.has(slot):
		equipment_data.equipped_items[slot] = null
		emit_signal("equipment_changed") # This triggers stat recalculation on the server's puppet.
