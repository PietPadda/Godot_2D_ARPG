# item_data.gd
# A data container for all item properties.
class_name ItemData
extends Resource

# Description
## A data container for all item properties.

# Defines the possible slots an item can be equipped in.
enum EquipmentSlot { NONE, WEAPON, ARMOR }

@export var item_name: String = "New Item"
@export var texture: Texture2D
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
# This dictionary will hold stat bonuses, e.g., {"damage": 10, "strength": 5}
@export var stat_modifiers: Dictionary = {}
