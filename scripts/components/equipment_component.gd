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
		equipment_data.equipped_items[item.equipment_slot] = item # equip in slot
		emit_signal("equipment_changed") # event signal
		print("EquipmentComponent: equipment_changed signal emitted.")
		print("Equipped: ", item.item_name) # debug print

# Unequips an item from a specific slot.
func unequip_item_by_slot(slot: ItemData.EquipmentSlot) -> void:
	if equipment_data.equipped_items.has(slot):
		var item = equipment_data.equipped_items[slot]
		if item:
			equipment_data.equipped_items[slot] = null
			emit_signal("equipment_changed") # Announce the change
			print("EquipmentComponent: equipment_changed signal emitted.")
			print("Unequipped: ", item.item_name)
