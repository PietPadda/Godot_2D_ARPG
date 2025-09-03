# inventory_slot.gd
extends PanelContainer

# signals
signal slot_clicked(item_data)
# announce when to show or hide a tooltip for our item
signal show_tooltip(item_data, slot_node)
signal hide_tooltip()

# vars
var current_item: ItemData # Astore the item

# scene nodes
@onready var item_texture: TextureRect = $ItemTexture

func _ready() -> void:
	# Connect the Control node's built-in mouse signals to our functions.
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

# ---Public API---
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

# ---Signal Handlers---
# clicking a slot
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if current_item:
			emit_signal("slot_clicked", current_item)

# mouse hovering over slot
func _on_mouse_entered() -> void:
	# If there's an item in this slot, tell the manager to show its tooltip.
	if current_item:
		emit_signal("show_tooltip", current_item, self)

# mouse move away from slot
func _on_mouse_exited() -> void:
	# Tell the manager to hide the tooltip, regardless of what's in the slot.
	emit_signal("hide_tooltip")
