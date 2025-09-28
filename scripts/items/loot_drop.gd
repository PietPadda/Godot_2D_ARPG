# loot_drop.gd
class_name LootDrop
extends Area2D

# We no longer need the @onready var here, as it can cause race conditions.
# @onready var sprite: Sprite2D = $Sprite2D

# This will be set via RPC after the node is spawned.
var item_data: ItemData

# Add a _physics_process function to this script
func _physics_process(_delta: float) -> void:
	pass

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
	var peer_id = multiplayer.get_unique_id()
	
	# --- DEBUG TRACE 1 ---
	# Did the RPC arrive with the correct item_path string?
	print("[%s] Initialize RPC received. Attempting to load item_path: '%s'" % [peer_id, item_path])
	
	# This function will now run on the server and all clients.
	if item_path.is_empty():
		# If something went wrong, just delete this node to prevent ghost items.
		queue_free()
		return
		
	# Set the position FIRST, while the object is still invisible.
	global_position = pos
	
	# --- DEBUG TRACE 2 ---
	# Did `load()` work? What did it return?
	var loaded_data = load(item_path)
	print("[%s] Result of load(item_path): %s" % [peer_id, loaded_data])
	
	# Load the resource from the given path.
	self.item_data = load(item_path)	
	
	# --- DEBUG TRACE 3 ---
	# Did the assignment happen? What is the variable's value now?
	print("[%s] self.item_data is now: %s" % [peer_id, self.item_data])
	
	# --- THIS IS THE FIX ---
	# Get a direct reference to the sprite node inside the RPC.
	# This avoids the @onready race condition.
	var sprite: Sprite2D = $Sprite2D
	
	# We now load the texture from the explicit path sent via the RPC.
	# This will run on the host AND the client, setting the correct texture.
	if item_data and not texture_path.is_empty():
		sprite.texture = load(texture_path)
	else:
		# --- DEBUG TRACE 4 ---
		# If we can't set the texture, let's find out why.
		print("[%s] Could not set texture. is_instance_valid(item_data): %s" % [peer_id, is_instance_valid(self.item_data)])
		
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
