# game_manager.gd
extends Node

const SAVE_PATH = "user://savegame.tres"

# We need a reference to our new database.
@onready var item_database: Node = get_node("/root/ItemDatabase")

# Preloading the Player script ensures Godot knows about the "Player" type
# when it parses the rest of this file.
const Player = preload("res://scripts/player/player.gd")

# This variable will temporarily hold our loaded data during a scene change.
var loaded_player_data: SaveData = null
# This variable will hold our player's data during a normal scene transition.
var player_data_on_transition: SaveData = null

# This dictionary will store the data for all players during a transition.
# The key will be the player's ID.
var all_players_transition_data: Dictionary = {}

# The ID of the player who triggered the scene transition.
var requesting_player_id: int = 0
# The target spawn location in the next scene for the requesting player.
var target_spawn_position: Vector2 = Vector2.INF

# This will be our central, authoritative list of all players in the game.
var active_players: Dictionary = {} # Format: { player_id: player_node }

func _ready() -> void:
	# Listen for when the player we control has spawned into a scene.
	EventBus.local_player_spawned.connect(_on_local_player_spawned)
	#Listen for when a player disconnects from the server.
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

# --- Public API ---
# Grabs the current player's data and stores it in memory for a scene transition.
## Save chardata between scene transitions
func carry_player_data() -> void:
	var player = get_tree().get_first_node_in_group("player") # get player
	if !is_instance_valid(player):
		push_error("GameManager: Could not find player to carry data for scene transition.")
		return # CRITICAL: We must stop execution if the player isn't found.
	
		# Guard Clauses: Validate components before accessing their data.
	var stats_component: StatsComponent = player.get_node("StatsComponent")
	var inventory_component: InventoryComponent = player.get_node("InventoryComponent")
	var equipment_component: EquipmentComponent = player.get_node("EquipmentComponent")
	if !is_instance_valid(stats_component) or !is_instance_valid(inventory_component) or !is_instance_valid(equipment_component):
		push_error("carry_player_data failed: Player is missing one or more data components.")
		return
	
	# We create a new SaveData resource to hold the current data.
	# We use .duplicate() to ensure it's a unique copy.
	var current_data = SaveData.new()
	current_data.player_stats_data = stats_component.stats_data.duplicate(true)
	current_data.player_inventory_data = inventory_component.inventory_data.duplicate(true)
	current_data.player_equipment_data = equipment_component.equipment_data.duplicate(true)
	
	# Store the player's live health and mana.
	current_data.current_health = stats_component.current_health
	current_data.current_mana = stats_component.current_mana
	
	player_data_on_transition = current_data # save prescene change data
	print("Carrying player data for scene transition.")

## Save player's game
func save_game() -> void:
	# get Player for components
	var player = get_tree().get_first_node_in_group("player")
	if !is_instance_valid(player):
		push_error("Save failed: Player node not found in the scene.")
		return

	# Guard Clauses: Ensure all required components exist before trying to access their data.
	var stats_component: StatsComponent = player.get_node("StatsComponent")
	var inventory_component: InventoryComponent = player.get_node("InventoryComponent")
	var equipment_component: EquipmentComponent = player.get_node("EquipmentComponent")
	
	if !is_instance_valid(stats_component) or !is_instance_valid(inventory_component) or !is_instance_valid(equipment_component):
		push_error("Save failed: Player is missing one or more data components (Stats, Inventory, or Equipment).")
		return
	
	var save_data = SaveData.new() # define save data
	
	# Duplicating the resources creates a unique snapshot of the data for saving.
	save_data.player_stats_data = stats_component.stats_data.duplicate() # update with player stats
	save_data.player_inventory_data = inventory_component.inventory_data.duplicate() # update with player items
	save_data.player_equipment_data = equipment_component.equipment_data.duplicate() # update with player eq
	
	# ResourceSaver.save() returns an error code, which we can check for success.
	var error = ResourceSaver.save(save_data, SAVE_PATH) # error check
	if error == OK: # will not print if save failed or error occured
		print("Game saved successfully!")
	else:
		push_error("An error occurred while saving the game. Error code: %s" % error)

## Load player's game and restart level
func load_game() -> void:
	# Guard Clause: Check if the save file actually exists before trying to load it.
	if !FileAccess.file_exists(SAVE_PATH):
		push_warning("No save file found at path: %s" % SAVE_PATH)
		return
		
	# Stop the current music before reloading.
	Music.stop_music()

	var loaded_resource = ResourceLoader.load(SAVE_PATH)
	
	# Guard Clause: Verify that the loaded file is a valid SaveData resource.
	# This prevents crashes from corrupted or incorrect file types.
	if !loaded_resource is SaveData:
		push_error("Failed to load game: The file at %s is not a valid SaveData resource." % SAVE_PATH)
		# Clear any potentially bad data before returning.
		loaded_player_data = null
		return
	
	# Create a deep, unique copy of the loaded data to break its link to the file.
	loaded_player_data = loaded_resource.duplicate(true)
		
	EventBus.change_game_state(EventBus.GameState.GAMEPLAY)
		
	# Reload the scene to apply the loaded data.
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	print("Game loaded!")
	
# NEW: This is now our single function for packaging up any player's data.
func get_player_data_as_dictionary(player_node: Node) -> Dictionary:
	if not is_instance_valid(player_node):
		return {}
		
	# Use the same dictionary logic from GameManager to build the data package.
	var stats_res = player_node.stats_component.stats_data
	var inventory_res = player_node.inventory_component.inventory_data
	var equipment_res = player_node.equipment_component.equipment_data

	var stats_dict = {}
	for prop in stats_res.get_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE and prop.name != "script":
			stats_dict[prop.name] = stats_res.get(prop.name)

	var inv_items_paths = []
	for item in inventory_res.items:
		if is_instance_valid(item): inv_items_paths.append(item.resource_path)

	var equipped_items_paths = {}
	for slot in equipment_res.equipped_items:
		var item = equipment_res.equipped_items[slot]
		if is_instance_valid(item): equipped_items_paths[slot] = item.resource_path
	
	var data_dictionary = {
		"stats_data": stats_dict,
		"inventory_items": inv_items_paths,
		"equipped_items": equipped_items_paths,
		"current_health": player_node.stats_component.current_health,
		"current_mana": player_node.stats_component.current_mana,
	}
	
	# Add the target spawn position logic here.
	if int(player_node.name) == requesting_player_id:
		data_dictionary["target_spawn_position"] = target_spawn_position
	else:
		data_dictionary["target_spawn_position"] = Vector2.INF
		
	return data_dictionary
		
func register_player(player_node: Node) -> void:
	var player_id = int(player_node.name)
	
	# REMOVE the 'if not active_players.has(player_id):' check.
	# We MUST always update the dictionary with the newest player instance
	# to overwrite any stale reference from a previous scene.
	active_players[player_id] = player_node
	print("[SERVER] Player %s registered." % player_id)
	
	# REMOVED: We no longer send the data immediately upon registration.
	# We will now wait for the player to request it.

func unregister_player(player_node: Node) -> void:
	var player_id = int(player_node.name)
	if active_players.has(player_id):
		active_players.erase(player_id)
		print("[SERVER] Player %s unregistered." % player_id)

func get_player(player_id: int) -> Node:
	return active_players.get(player_id, null)
	
# This is called by the player's RPC after they have loaded into the new scene.
func send_transition_data_to_player(player_id: int):
	print("[SERVER] Received a request to send transition data to player ID: ", player_id)
	
	# Make sure we actually have a player and data for this ID.
	if all_players_transition_data.has(player_id) and active_players.has(player_id):
		print("[SERVER] SUCCESS: Found data and active player node for ID: ", player_id, ". Sending now.")
		
		var player_node = active_players[player_id]
		
		# THE FIX: Directly get the DICTIONARY that was already prepared and stored.
		# The line that tried to treat this as a SaveData object is the source of the crash and is removed.
		var data_dictionary = all_players_transition_data[player_id]
		
		# This debug print is still useful to verify the data being sent.
		print("[SERVER] Data dictionary being sent to player %s: " % player_id, JSON.stringify(data_dictionary, "\t", false))

		# THE FIX: Update the server's local puppet with the data first.
		player_node._apply_data_dictionary(data_dictionary)
		# Send the dictionary via RPC.
		player_node.client_apply_transition_data.rpc_id(player_id, data_dictionary)
		
		# Clean up the data after it's been sent.
		all_players_transition_data.erase(player_id)
	else:
		print("[SERVER] FAILURE: Could not send data to player ID: ", player_id)
		if not all_players_transition_data.has(player_id):
			print("     - Reason: No transition data was stored for this ID.")
		if not active_players.has(player_id):
			print("     - Reason: This player is not registered as active in the new scene.")

# -- Signal Handlers --
# This function is called by the EventBus when the player is ready.
func _on_local_player_spawned(player: Player) -> void:
	# Check if we have save game data to apply.
	if is_instance_valid(loaded_player_data):
		player.apply_persistent_data(loaded_player_data, false)
		# Clear the data after it's been used.
		loaded_player_data = null
	# Check if we have scene transition data to apply.
	elif is_instance_valid(player_data_on_transition):
		player.apply_persistent_data(player_data_on_transition, true)
		# Clear the data after it's been used.
		player_data_on_transition = null
		
# This function will only be called on the server when a client disconnects.
func _on_player_disconnected(player_id: int) -> void:
	# Find the player's node using our existing registry function.
	var player_node = get_player(player_id)
	if is_instance_valid(player_node):
		# Now, unregister them from the central list.
		unregister_player(player_node)
