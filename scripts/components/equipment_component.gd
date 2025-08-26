# equipment_component.gd
class_name EquipmentComponent
extends Node

# expose for resource field
@export var equipment_data: EquipmentData

# Equips an item into its designated slot.
func equip_item(item: ItemData) -> void:
	if item.equipment_slot != ItemData.EquipmentSlot.NONE: # if it's equippable
		equipment_data.equipped_items[item.equipment_slot] = item # equip in slot
		print("Equipped: ", item.item_name) # debug print
