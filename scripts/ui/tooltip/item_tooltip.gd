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
		
		# "modifier" is now a StatModifier resource object.
		for modifier in item_data.stat_modifiers:
			# Get the value directly from the modifier resource.
			var value = modifier.value
			# Get the string name by looking up the enum in our global singleton.
			var stat_name = Stats.STAT_NAMES[modifier.stat]
			# Add a '+' for positive values.
			var symbol = "+" if value >= 0 else ""
			# We'll use a different color for stats to make them stand out.
			# colour = [color=aqua]...[/color]
			tooltip_label.append_text("[color=aqua]%s%s %s[/color]\n" % [symbol, value, stat_name.capitalize()])
