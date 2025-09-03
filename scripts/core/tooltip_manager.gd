# scripts/core/tooltip_manager.gd
# A global manager for showing, hiding, and positioning the item tooltip.
class_name TooltipManager
extends CanvasLayer

# ---Scene Nodes--- 
@onready var item_tooltip: ItemTooltip = $ItemTooltip

# ---Private Vars--- 
# We store the currently hovered slot to prevent flickering.
var _current_hovered_slot: Control = null

func _ready() -> void:
	# Start with the tooltip hidden.
	item_tooltip.hide()

# ---Public API---
# Called by UI slots when the mouse enters their bounds.
func show_tooltip(item_data: ItemData, slot_node: Control) -> void:
	if not item_data or not is_instance_valid(slot_node):
		return
	
	_current_hovered_slot = slot_node
	item_tooltip.update_tooltip(item_data)
	# Use call_deferred to wait one frame for the tooltip's size to update.
	call_deferred("_position_tooltip")
	item_tooltip.show()

# Called by UI slots when the mouse exits their bounds.
func hide_tooltip(slot_node: Control) -> void:
	# Only hide the tooltip if the mouse is exiting the slot we're currently showing.
	# This prevents a tooltip from being hidden when moving between adjacent slots.
	if _current_hovered_slot == slot_node:
		item_tooltip.hide()
		_current_hovered_slot = null

# ---Private Methods---
# Positions the tooltip to the right of the mouse cursor.
func _position_tooltip() -> void:
	# Wait for the end of the frame to ensure the tooltip's size is calculated.
	await get_tree().process_frame
	
	var mouse_pos = get_viewport().get_mouse_position()
	var tooltip_size = item_tooltip.size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Default position is to the right and down.
	var new_pos = mouse_pos + Vector2(20, 20)
	
	# If the tooltip would go off the right edge, flip it to the left.
	if new_pos.x + tooltip_size.x > viewport_size.x:
		new_pos.x = mouse_pos.x - tooltip_size.x - 20
		
	# If the tooltip would go off the bottom edge, flip it up.
	if new_pos.y + tooltip_size.y > viewport_size.y:
		new_pos.y = mouse_pos.y - tooltip_size.y - 20
		
	item_tooltip.global_position = new_pos
