# loot_drop.gd
class_name LootDrop
extends Area2D

# scene nodes
@onready var sprite: Sprite2D = $Sprite2D

# This will store the item data for this specific drop.
var item_data: ItemData

# This function will be called by whatever spawns the loot.
func initialize(data: ItemData) -> void:
	self.item_data = data
	sprite.texture = data.texture

func _on_body_entered(body: Node2D) -> void:
	# First, check if the item is currency.
	if item_data.item_type == ItemData.ItemType.CURRENCY:
		var stats_component: StatsComponent = body.get_node_or_null("StatsComponent")
		if stats_component:
			# If it is, call the add_gold function and disappear.
			stats_component.add_gold(item_data.value)
			queue_free()
		return # Stop further processing for this item.

	# If it's not currency, run the original inventory logic.
	# Check if the body that entered is the player.
	var inventory_component: InventoryComponent = body.get_node_or_null("InventoryComponent")
	if inventory_component:
		#Try to add our item to their inventory.
		var picked_up = inventory_component.add_item(item_data)
		#If the item was successfully picked up, destroy the loot drop.
		if picked_up:
			queue_free()
