# scripts/ui/player_inventory.gd
extends PanelContainer

# scene nodes
@onready var inventory_panel = %InventoryPanel # Make InventoryPanel a unique name
@onready var weapon_slot: PanelContainer = $HBoxContainer/VBoxContainer/WeaponSlot
@onready var armor_slot: PanelContainer = $HBoxContainer/VBoxContainer/ArmorSlot
@onready var helm_slot: PanelContainer = $HBoxContainer/VBoxContainer/HelmSlot
@onready var boots_slot: PanelContainer = $HBoxContainer/VBoxContainer/BootsSlot
@onready var gold_label: Label = %GoldLabel # unique name rather than child node

# Remove the setter functions. These are now just regular variables.
var inventory_component: InventoryComponent
var equipment_component: EquipmentComponent
var stats_component: StatsComponent

# This is our new, explicit setup function.
func initialize(inv_comp: InventoryComponent, equip_comp: EquipmentComponent, stats_comp: StatsComponent):
	inventory_component = inv_comp
	equipment_component = equip_comp
	stats_component = stats_comp

	# Connect to the data component signals
	inventory_component.inventory_changed.connect(redraw)
	equipment_component.equipment_changed.connect(redraw)
	stats_component.gold_changed.connect(_on_gold_changed)

	# Initialize the UI
	inventory_panel.initialize_inventory(inventory_component.inventory_data)
	# Connect to the UI slots now that they've been created
	for slot in inventory_panel.grid_container.get_children():
		# This panel interprets a left-click as an "equip item" request.
		if !slot.slot_left_clicked.is_connected(_on_inventory_slot_clicked):
			slot.slot_left_clicked.connect(_on_inventory_slot_clicked)
			
		# NEW: This panel interprets a right-click as a "drop item" request.
		if !slot.slot_right_clicked.is_connected(_on_item_drop_requested):
			slot.slot_right_clicked.connect(_on_item_drop_requested)
			
		# Inventory Tooltip calls
		if !slot.show_tooltip.is_connected(Tooltip.show_tooltip):
			slot.show_tooltip.connect(Tooltip.show_tooltip)
		if !slot.hide_tooltip.is_connected(Tooltip.hide_tooltip):
			slot.hide_tooltip.connect(Tooltip.hide_tooltip.bind(slot)) # Bind the slot node as an argument
	
	# Equipment Tooltip calls
	if not weapon_slot.show_tooltip.is_connected(Tooltip.show_tooltip):
		weapon_slot.show_tooltip.connect(Tooltip.show_tooltip)
	if not weapon_slot.hide_tooltip.is_connected(Tooltip.hide_tooltip):
		weapon_slot.hide_tooltip.connect(Tooltip.hide_tooltip.bind(weapon_slot))
	if not armor_slot.show_tooltip.is_connected(Tooltip.show_tooltip):
		armor_slot.show_tooltip.connect(Tooltip.show_tooltip)
	if not armor_slot.hide_tooltip.is_connected(Tooltip.hide_tooltip):
		armor_slot.hide_tooltip.connect(Tooltip.hide_tooltip.bind(armor_slot))
	if not helm_slot.show_tooltip.is_connected(Tooltip.show_tooltip):
		helm_slot.show_tooltip.connect(Tooltip.show_tooltip)
	if not helm_slot.hide_tooltip.is_connected(Tooltip.hide_tooltip):
		helm_slot.hide_tooltip.connect(Tooltip.hide_tooltip.bind(helm_slot))
	if not boots_slot.show_tooltip.is_connected(Tooltip.show_tooltip):
		boots_slot.show_tooltip.connect(Tooltip.show_tooltip)
	if not boots_slot.hide_tooltip.is_connected(Tooltip.hide_tooltip):
		boots_slot.hide_tooltip.connect(Tooltip.hide_tooltip.bind(boots_slot))
	
	# Manually draw once on init to show initial state
	redraw()

func _ready() -> void:
	# Connect signals from the UI slots to our controller logic.
	weapon_slot.slot_clicked.connect(_on_equipment_slot_clicked)
	armor_slot.slot_clicked.connect(_on_equipment_slot_clicked)
	helm_slot.slot_clicked.connect(_on_equipment_slot_clicked)
	boots_slot.slot_clicked.connect(_on_equipment_slot_clicked)

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
	if not is_instance_valid(inventory_component) or not is_instance_valid(equipment_component) or not is_instance_valid(stats_component):
		return
	
	inventory_panel.redraw(inventory_component.inventory_data)
	weapon_slot.update_slot(equipment_component.equipment_data.equipped_items[ItemData.EquipmentSlot.WEAPON])
	armor_slot.update_slot(equipment_component.equipment_data.equipped_items[ItemData.EquipmentSlot.ARMOR])
	helm_slot.update_slot(equipment_component.equipment_data.equipped_items[ItemData.EquipmentSlot.HELM])
	boots_slot.update_slot(equipment_component.equipment_data.equipped_items[ItemData.EquipmentSlot.BOOTS])
	_on_gold_changed(stats_component.stats_data.gold)

# -- Signal Handlers --
# This function is called when the StatsComponent emits the "gold_changed" signal.
func _on_gold_changed(total_gold: int) -> void:
	gold_label.text = "Gold: " + str(total_gold)

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
	
# This function is called when an inventory slot is right-clicked.
func _on_item_drop_requested(item_data: ItemData) -> void:
	print("Player requested to drop: ", item_data.item_name)
	# Remove the item from the player's inventory component.
	inventory_component.remove_item(item_data)
	# In the next step, we will add an RPC call here to tell the server
	# to spawn the item on the ground.
