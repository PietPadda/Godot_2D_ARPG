# scripts/ui/tooltip/item_tooltip.gd
# A reusable UI element for displaying item information.
class_name ItemTooltip
extends PanelContainer

# Scene Nodes
@onready var tooltip_label: RichTextLabel = $TooltipLabel

# Public API
# Updates the tooltip's content based on the provided item data.
func update_tooltip(item_data: ItemData) -> void:
	if not item_data:
		return # early return if not item data

	# Start with a clean slate.
	tooltip_label.clear()

	# Add the item name in bold. We use BBCode for rich text formatting.
	# bold = [b]...[/b]
	tooltip_label.append_text("[b]" + item_data.item_name + "[/b]\n") 

	# Add the stat modifiers.
	if not item_data.stat_modifiers.is_empty():
		tooltip_label.append_text("\n") # Add a space before stats
		
		for stat in item_data.stat_modifiers:
			var value = item_data.stat_modifiers[stat]
			# Add a '+' for positive values.
			var sign = "+" if value >= 0 else ""
			# We'll use a different color for stats to make them stand out.
			# colour = [color=aqua]...[/color]
			tooltip_label.append_text("[color=aqua]%s%s %s[/color]\n" % [sign, value, stat.capitalize()])
