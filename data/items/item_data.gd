# item_data.gd
# A data container for all item properties.
class_name ItemData
extends Resource

# Description
## A data container for all item properties.

# Defines the possible slots an item can be equipped in.
enum EquipmentSlot { NONE, WEAPON, ARMOR, HELM, BOOTS }
# Defines the type of the item.
enum ItemType { REGULAR, CURRENCY }

@export var item_name: String = "New Item"
@export var texture: Texture2D
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
# item type and a value for currency.
@export var item_type: ItemType = ItemType.REGULAR
@export var value: int = 1 # Used for gold amount, etc.
# This dictionary will hold stat bonuses, e.g., {"damage": 10, "strength": 5}
@export var stat_modifiers: Dictionary = {}
