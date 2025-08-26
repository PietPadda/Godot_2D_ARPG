# equipment_data.gd
class_name EquipmentData
extends Resource

# Description
## A data container for all equipment properties.

# A dictionary to hold the currently equipped items, indexed by slot.
var equipped_items: Dictionary = {
	ItemData.EquipmentSlot.WEAPON: null,
	ItemData.EquipmentSlot.ARMOR: null
}
