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

	# We send the RPC request to the server (peer_id = 1) and include our own ID.
	server_request_pickup.rpc_id(1, body.get_multiplayer_authority())

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

## Networked loot pickup
@rpc("any_peer", "call_local", "reliable")
func server_request_pickup(picker_id: int):
	# This code ONLY runs on the server.
	
	# This safety check is important because item_data might be null for a split second
	# before the RPC arrives.
	if not item_data:
		return
		
	#Find the player node using the ID we received.
	var player_node = get_tree().get_root().get_node_or_null("Main/PlayerContainer/" + str(picker_id))
	if not is_instance_valid(player_node):
		return
		
	# First, check if the item is currency.
	if item_data.item_type == ItemData.ItemType.CURRENCY:
		var stats_component: StatsComponent = player_node.get_node_or_null("StatsComponent")
		if stats_component:
			# If it is, call the add_gold function and disappear.
			stats_component.add_gold(item_data.value)
			queue_free() # If it's gold, we're done. The server destroys the item.
		return # Stop further processing for this item.

	# If it's a regular item, try to add it to the inventory.
	var inventory_component: InventoryComponent = player_node.get_node_or_null("InventoryComponent")
	if inventory_component:
		#Try to add our item to their inventory.
		var picked_up = inventory_component.add_item(item_data)
		#If the item was successfully picked up, the server destroys the loot drop.
		if picked_up:
			queue_free()
