# inventory_slot.gd
extends PanelContainer

# signals
signal slot_clicked(item_data)

# vars
var current_item: ItemData # Astore the item

# scene nodes
@onready var item_texture: TextureRect = $ItemTexture

# Updates the slot to display an item, or clears it if item_data is null.
## inventory slot update with itemdata texture
func update_slot(item_data: ItemData) -> void:
	current_item = item_data # Store the item
	if item_data: # if it's a valid item, apply texture
		item_texture.texture = item_data.texture
		item_texture.visible = true
	else:  # otherwise, not an item
		item_texture.texture = null
		item_texture.visible = false

# Add this new function and connect the gui_input signal to it
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if current_item:
			emit_signal("slot_clicked", current_item)
