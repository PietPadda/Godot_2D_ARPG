# character_sheet.gd
extends PanelContainer

# scene nodes
@onready var inventory_panel = %InventoryPanel # Make InventoryPanel a unique name
@onready var weapon_slot: PanelContainer = $HBoxContainer/VBoxContainer/WeaponSlot
@onready var armor_slot: PanelContainer = $HBoxContainer/VBoxContainer/ArmorSlot

# These setters will run automatically when the HUD assigns the components.
# inventory setter
var inventory_component: InventoryComponent:
	set(value):
		inventory_component = value
		# Connect to the signal that announces data changes.
		inventory_component.inventory_changed.connect(redraw) # redraw on any inv changes!
		# Initialize the UI with the inventory data ONE time.
		inventory_panel.initialize_inventory(inventory_component.inventory_data)

# equipment setter
var equipment_component: EquipmentComponent:
	set(value):
		equipment_component = value

func _ready() -> void:
	# Connect signals from the UI slots to our controller logic.
	weapon_slot.slot_clicked.connect(_on_equipment_slot_clicked)
	armor_slot.slot_clicked.connect(_on_equipment_slot_clicked)
	
	# We must wait for the inventory_panel to create its slots before connecting to them.
	await inventory_panel.ready
	# We need to connect to every slot in the inventory.
	for slot in inventory_panel.grid_container.get_children():
		slot.slot_clicked.connect(_on_inventory_slot_clicked)

# When an inventory item is clicked, try to equip it.
func _on_inventory_slot_clicked(item_data: ItemData) -> void:
	# Ignore clicks on non-equippable items.
	if item_data.equipment_slot == ItemData.EquipmentSlot.NONE:
		return
		
	# Check if an item is already in that slot, and unequip it first.
	var slot_type = item_data.equipment_slot
	var current_item = equipment_component.equipment_data.equipped_items[slot_type]
	
	# If a different item is already in that slot, unequip it first.
	if current_item:
		_unequip_item(slot_type, current_item)

	equipment_component.equip_item(item_data) # add item to eq
	inventory_component.remove_item(item_data) # then remove from inv
	# The redraw will happen automatically via the inventory_changed signal.

# When an equipped item is clicked, unequip it.
func _on_equipment_slot_clicked(slot_type: ItemData.EquipmentSlot, item_data: ItemData) -> void:
	_unequip_item(slot_type, item_data)

# unequip is now an internal only private helper
func _unequip_item(slot_type: ItemData.EquipmentSlot, item_data: ItemData) -> void:
	# The add_item function returns true if it succeeds.
	# Check if inventory has space before unequipping.
	if inventory_component.add_item(item_data):
		equipment_component.equipment_data.equipped_items[slot_type] = null
	# Redraw will also happen automatically here.

# A central function to update all UI elements.
func redraw() -> void:
	# Check if the components are ready before redrawing.
	if not is_instance_valid(inventory_component) or not is_instance_valid(equipment_component):
		return
	
	inventory_panel.redraw(inventory_component.inventory_data)
	weapon_slot.update_slot(equipment_component.equipment_data.equipped_items[ItemData.EquipmentSlot.WEAPON])
	armor_slot.update_slot(equipment_component.equipment_data.equipped_items[ItemData.EquipmentSlot.ARMOR])
