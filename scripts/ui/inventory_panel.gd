# inventory_panel.gd
extends PanelContainer

# preload to instantiate
const InventorySlot = preload("res://scenes/ui/inventory_slot.tscn")

# scene nodes
## grid from inventory panel scene
@onready var grid_container: GridContainer = %GridContainer # % is shorthand for unique name

# This will be called from the HUD when the game starts.
## create all inv slots at startup
func initialize_inventory(inventory_data: InventoryData) -> void:
	# This function now creates all the slots ONE TIME.
	for i in inventory_data.capacity:
		var slot = InventorySlot.instantiate()
		grid_container.add_child(slot)
		slot.update_slot(null) # Start empty

# Redraws all slots based on the inventory data.
## inventory redraw
func redraw(inventory_data: InventoryData) -> void:
	# get all the slots
	var slots = grid_container.get_children()
	
	# Loop through all existing slots.
	for i in slots.size():
		# If there's an item for this slot, update it.
		if i < inventory_data.items.size():
			slots[i].update_slot(inventory_data.items[i])
		# Otherwise, tell the slot to be empty.
		else:
			slots[i].update_slot(null)
