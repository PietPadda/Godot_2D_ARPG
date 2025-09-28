# loot_drop.gd
class_name LootDrop
extends Area2D

# scene nodes
@onready var sprite: Sprite2D = $Sprite2D

# This will be set via RPC after the node is spawned.
var item_data: ItemData

# Add a _physics_process function to this script
func _physics_process(_delta: float) -> void:
	# --- ADD THIS DEBUG CODE ---
	if not multiplayer.is_server():
		# This print statement will only run on the client's machine.
		print("CLIENT LOOT: visible property is %s, is_visible_in_tree() is %s" % [visible, is_visible_in_tree()])

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
func initialize(item_path: String, pos: Vector2, texture_path: String):
	# This function will now run on the server and all clients.
	if item_path.is_empty():
		# If something went wrong, just delete this node to prevent ghost items.
		queue_free()
		return
		
	# Set the position FIRST, while the object is still invisible.
	global_position = pos
	
	# Load the resource from the given path.
	self.item_data = load(item_path)	
	
	# --- THIS IS THE FIX ---
	# We now load the texture from the explicit path sent via the RPC.
	# This will run on the host AND the client, setting the correct texture.
	if item_data and not texture_path.is_empty():
		sprite.texture = load(texture_path)
		
	# Now that everything is perfectly set up, make it visible.
	visible = true
	
	# If we are the server, kick off the synchronizer handshake.
	if multiplayer.is_server():
		var level = LevelManager.get_current_level()
		if is_instance_valid(level):
			level.make_node_visible_to_all(get_path())

## Networked loot pickup
@rpc("any_peer", "call_local", "reliable")
func server_request_pickup(picker_id: int):
	# This code ONLY runs on the server.
	
	# This safety check is important because item_data might be null for a split second
	# before the RPC arrives.
	if not item_data:
		return
		
	# Instead of searching the scene tree, we ask our manager for the player.
	var player_node = GameManager.get_player(picker_id)
	
	if not is_instance_valid(player_node):
		return
		
	# First, check if the item is currency.
	if item_data.item_type == ItemData.ItemType.CURRENCY:
		var stats_component: StatsComponent = player_node.get_node_or_null("StatsComponent")
		if stats_component:
			# Server updates its master record.
			stats_component.add_gold(item_data.value)
			
			# Only send the RPC if the picker is NOT the server.
			if picker_id != 1:
				# Server SENDS COMMAND to the client to do the same.
				stats_component.client_add_gold.rpc_id(picker_id, item_data.value)
			
			# Server destroys the loot drop for everyone.
			queue_free()
		return # Stop further processing for this item.

	# If it's a regular item, try to add it to the inventory.
	var inventory_component: InventoryComponent = player_node.get_node_or_null("InventoryComponent")
	if inventory_component:
		# Server updates its master record.
		var picked_up = inventory_component.add_item(item_data)
		if picked_up:
			# Only send the RPC if the picker is NOT the server.
			if picker_id != 1:
				# Server SENDS COMMAND to the client to do the same.
				inventory_component.client_add_item.rpc_id(picker_id, item_data.resource_path)
			
			# Server destroys the loot drop for everyone.
			queue_free()
