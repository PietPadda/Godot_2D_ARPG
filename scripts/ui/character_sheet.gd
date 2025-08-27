# character_sheet.gd
extends PanelContainer

# This controller will manage the data flow between components.
var inventory_component: InventoryComponent
var equipment_component: EquipmentComponent

@onready var inventory_panel = %InventoryPanel # Make InventoryPanel a unique name
@onready var weapon_slot: PanelContainer = $HBoxContainer/VBoxContainer/WeaponSlot
@onready var armor_slot: PanelContainer = $HBoxContainer/VBoxContainer/ArmorSlot

func _ready() -> void:
	# Wait until the components are assigned before connecting signals.
	await owner.ready
	
	# Connect signals from the UI slots to our controller logic.
	weapon_slot.slot_clicked.connect(_on_equipment_slot_clicked)
	armor_slot.slot_clicked.connect(_on_equipment_slot_clicked)
	# We need to connect to every slot in the inventory.
	for slot in inventory_panel.grid_container.get_children():
		slot.slot_clicked.connect(_on_inventory_slot_clicked)

# When an inventory item is clicked, try to equip it.
func _on_inventory_slot_clicked(item_data: ItemData) -> void:
	# Check if an item is already in that slot, and unequip it first.
	var slot_type = item_data.equipment_slot
	var current_item = equipment_component.equipment_data.equipped_items[slot_type]
	if current_item:
		unequip_item(slot_type, current_item)

	equipment_component.equip_item(item_data)
	inventory_component.remove_item(item_data)
	redraw()

# When an equipped item is clicked, unequip it.
func _on_equipment_slot_clicked(slot_type: ItemData.EquipmentSlot, item_data: ItemData) -> void:
	unequip_item(slot_type, item_data)

func unequip_item(slot_type: ItemData.EquipmentSlot, item_data: ItemData) -> void:
	# Check if inventory has space before unequipping.
	if inventory_component.add_item(item_data):
		equipment_component.equipment_data.equipped_items[slot_type] = null
	redraw()

# A central function to update all UI elements.
func redraw() -> void:
	inventory_panel.redraw(inventory_component.inventory_data)
	weapon_slot.update_slot(equipment_component.equipment_data.equipped_items[ItemData.EquipmentSlot.WEAPON])
	armor_slot.update_slot(equipment_component.equipment_data.equipped_items[ItemData.EquipmentSlot.ARMOR])
