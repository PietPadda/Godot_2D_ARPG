# inventory_slot.gd
extends PanelContainer

# scene nodes
@onready var item_texture: TextureRect = $ItemTexture

# Updates the slot to display an item, or clears it if item_data is null.
## inventory slot update with itemdata texture
func update_slot(item_data: ItemData) -> void:
	if item_data: # if it's a valid item, apply texture
		item_texture.texture = item_data.texture
		item_texture.visible = true
	else:  # otherwise, not an item
		item_texture.texture = null
		item_texture.visible = false
