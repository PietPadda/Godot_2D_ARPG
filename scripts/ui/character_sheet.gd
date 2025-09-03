# character_sheet.gd
extends PanelContainer

# scene nodes
@onready var inventory_panel = %InventoryPanel # Make InventoryPanel a unique name
@onready var weapon_slot: PanelContainer = $HBoxContainer/VBoxContainer/WeaponSlot
@onready var armor_slot: PanelContainer = $HBoxContainer/VBoxContainer/ArmorSlot

# Remove the setter functions. These are now just regular variables.
var inventory_component: InventoryComponent
var equipment_component: EquipmentComponent

# This is our new, explicit setup function.
func initialize(inv_comp: InventoryComponent, equip_comp: EquipmentComponent):
	self.inventory_component = inv_comp
	self.equipment_component = equip_comp

	# Connect to the data component signals
	inventory_component.inventory_changed.connect(redraw)
	equipment_component.equipment_changed.connect(redraw)

	# Initialize the UI
	inventory_panel.initialize_inventory(inventory_component.inventory_data)
	# Connect to the UI slots now that they've been created
	for slot in inventory_panel.grid_container.get_children():
		slot.slot_clicked.connect(_on_inventory_slot_clicked)
		# Inventory Tooltip calls
		slot.show_tooltip.connect(Tooltip.show_tooltip)
		slot.hide_tooltip.connect(Tooltip.hide_tooltip.bind(slot)) # Bind the slot node as an argument
	
	# Equipment Tooltip calls
	weapon_slot.show_tooltip.connect(Tooltip.show_tooltip)
	weapon_slot.hide_tooltip.connect(Tooltip.hide_tooltip.bind(weapon_slot))
	armor_slot.show_tooltip.connect(Tooltip.show_tooltip)
	armor_slot.hide_tooltip.connect(Tooltip.hide_tooltip.bind(armor_slot))
	
	# Manually draw once on init to show initial state
	redraw()

func _ready() -> void:
	# Connect signals from the UI slots to our controller logic.
	weapon_slot.slot_clicked.connect(_on_equipment_slot_clicked)
	armor_slot.slot_clicked.connect(_on_equipment_slot_clicked)

# When an inventory item is clicked, try to equip it.
func _on_inventory_slot_clicked(item_data: ItemData) -> void:
	# Ignore clicks on non-equippable items.
	if item_data.equipment_slot == ItemData.EquipmentSlot.NONE:
		return
		
	var item_to_equip = item_data # item in inv
	var slot_to_fill = item_to_equip.equipment_slot # applicable slot
	# get current item from the same slot as equipped
	var currently_equipped_item = equipment_component.equipment_data.equipped_items[slot_to_fill]
	
	# equipping/swapping logic
	if currently_equipped_item == null: # if no item is equipped
		# Equipping to an EMPTY slot
		equipment_component.equip_item(item_to_equip) # equip item in inv
		inventory_component.remove_item(item_to_equip) # remove same item from inv
	else: # if an item in slot already equipped
		#  SWAPPING with an equipped item
		inventory_component.remove_item(item_to_equip) # renove item to equip from inv
		inventory_component.add_item(currently_equipped_item) # move prev item back to inv
		equipment_component.equip_item(item_to_equip) # equip item in inv

# When an equipped item is clicked, unequip it.
func _on_equipment_slot_clicked(slot_type: ItemData.EquipmentSlot, item_data: ItemData) -> void:
	_unequip_item(slot_type, item_data)

# unequip is now an internal only private helper
func _unequip_item(slot_type: ItemData.EquipmentSlot, item_data: ItemData) -> void:
	# The add_item function returns true if it succeeds.
	# Check if inventory has space before unequipping.
	if inventory_component.add_item(item_data):
		# Call the component's method instead of modifying its data directly.
		equipment_component.unequip_item_by_slot(slot_type)
	# Redraw will also happen automatically here.

# A central function to update all UI elements.
func redraw() -> void:
	# Check if the components are ready before redrawing.
	if not is_instance_valid(inventory_component) or not is_instance_valid(equipment_component):
		return
	
	inventory_panel.redraw(inventory_component.inventory_data)
	weapon_slot.update_slot(equipment_component.equipment_data.equipped_items[ItemData.EquipmentSlot.WEAPON])
	armor_slot.update_slot(equipment_component.equipment_data.equipped_items[ItemData.EquipmentSlot.ARMOR])
