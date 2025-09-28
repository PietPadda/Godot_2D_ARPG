# loot_drop.gd
class_name LootDrop
extends Area2D

# We no longer need the @onready var here, as it can cause race conditions.
# @onready var sprite: Sprite2D = $Sprite2D

# This will be set via RPC after the node is spawned.
var item_data: ItemData

# This path will be set by the server and synced to clients automatically.
@export var item_data_path: String = "":
	set(value):
		item_data_path = value
		# If the node is ready, run setup immediately when this value changes.
		if is_node_ready():
			_setup_loot()
			
func _ready() -> void:
	# The node is guaranteed to exist here, so we can safely run setup.
	_setup_loot()

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

# --- Private Functions ---
# This new function contains all our setup logic.
func _setup_loot() -> void:
	# Guard clause: Don't run if the path is empty or we already set it up.
	if item_data_path.is_empty() or is_instance_valid(item_data):
		return

	print("[%s] Setting up loot from synced path: '%s'" % [multiplayer.get_unique_id(), item_data_path])
	item_data = load(item_data_path)
	
	var sprite: Sprite2D = $Sprite2D
	if is_instance_valid(item_data) and is_instance_valid(sprite) and is_instance_valid(item_data.texture):
		sprite.texture = item_data.texture
	
	# Enable collision only after setup is complete.
	$CollisionShape2D.disabled = false
	
	# Enable sprite visibility now (prevent 0,0 spawn then sycn relocate 1 frame later)
	visible = true
	
	# If we are the server, we are responsible for telling all clients
	# that this node's synchronizer is now ready to be seen.
	if multiplayer.is_server():
		var level = LevelManager.get_current_level()
		if is_instance_valid(level):
			level.make_node_visible_to_all(get_path())

# --- RPCs ---
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
