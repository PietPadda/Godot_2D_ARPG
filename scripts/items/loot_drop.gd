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
	# Check if the body that entered is the player.
	if body.is_in_group("player"):
		# Get the player's inventory component.
		var inventory_component: InventoryComponent = body.get_node("InventoryComponent")

		# Try to add our item to their inventory.
		var picked_up = inventory_component.add_item(item_data)

		# If the item was successfully picked up, destroy the loot drop.
		if picked_up:
			queue_free()
