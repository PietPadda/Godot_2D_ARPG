# loot_drop.gd
class_name LootDrop
extends Area2D

# scene nodes
@onready var sprite: Sprite2D = $Sprite2D

# This will be set via RPC after the node is spawned.
var item_data: ItemData

# --- Signal Handlers ---
## Player enters the body of loot on the floor
func _on_body_entered(body: Node2D) -> void:
	# We only want the player who is in control to send the pickup request.
	if not body.is_multiplayer_authority():
		return

	# Instead of running the logic here, we ask the server to do it.
	# We send the RPC request to the server (peer_id = 1).
	server_request_pickup.rpc_id(1)
	'''
	# This safety check is important because item_data might be null for a split second
	# before the RPC arrives.
	if not item_data:
		return
		
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
			'''
			
# --- RPCs ---
# This function will be called by the server on all clients to set up the loot.
## Generate networked loot for all players
@rpc("any_peer", "call_local", "reliable")
func setup_loot(item_path: String):
	# If the path is empty, do nothing.
	if item_path.is_empty():
		return
	
	# Load the resource from the given path.
	self.item_data = load(item_path)
	
	# If we successfully loaded the item data, apply its texture.
	if item_data:
		sprite.texture = item_data.texture

## Clean picked up loot via server
@rpc("any_peer", "call_local", "reliable")
func server_request_pickup():
	# This code will ONLY run on the server.
	# The server will handle giving the item to the player and then destroying this loot drop.
	
	# For now, we'll just fix the crash by having the server destroy the object.
	# We'll sync the inventory in the next step.
	queue_free()
