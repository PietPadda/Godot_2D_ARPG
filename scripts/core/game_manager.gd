# game_manager.gd
extends Node

const SAVE_PATH = "user://savegame.tres"

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
#  This function grabs the current player's data and stores it for the transition.
## Save chardata between scene transitions
func carry_player_data() -> void:
	var player = get_tree().get_first_node_in_group("player") # get player
	if not player:
		push_error("GameManager: Could not find player to carry data.")
		return
	
	# get player's components
	var stats_component: StatsComponent = player.get_node("StatsComponent")
	var inventory_component: InventoryComponent = player.get_node("InventoryComponent")
	var equipment_component: EquipmentComponent = player.get_node("EquipmentComponent")
	
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
	if not player:
		print("Save failed: Player not found.")
		return

	# get player's components
	var stats_component: StatsComponent = player.get_node("StatsComponent")
	var inventory_component: InventoryComponent = player.get_node("InventoryComponent")
	var equipment_component: EquipmentComponent = player.get_node("EquipmentComponent")
	
	var save_data = SaveData.new() # define save data
	
	# By duplicating the resources, we create a unique snapshot of the player's
	# data, forcing Godot to save the actual values, not just a link.
	save_data.player_stats_data = stats_component.stats_data.duplicate() # update with player stats
	save_data.player_inventory_data = inventory_component.inventory_data.duplicate() # update with player items
	save_data.player_equipment_data = equipment_component.equipment_data.duplicate() # update with player eq
	
	var error = ResourceSaver.save(save_data, SAVE_PATH) # error check
	if error == OK: # will not print if save failed or error occured
		print("Game saved successfully!")

## Load player's game and restart level
func load_game() -> void:
	# check if file actually exists
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found.")
		return
		
	# Stop the current music before reloading.
	Music.stop_music()

	# Load the data from the file.
	var loaded_data: SaveData = ResourceLoader.load(SAVE_PATH)
	
	# Create a deep, unique copy of the loaded data.
	# This breaks the "live link" to the save file resource.
	if is_instance_valid(loaded_data):
		loaded_player_data = loaded_data.duplicate(true)
		
	# After loading, ALWAYS reset the game state to ensure the player has control.
	EventBus.change_game_state(EventBus.GameState.GAMEPLAY)
		
	# Now, reload the entire level. Diablo 2 style!!
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	print("Game loaded!")
	
# This function is called by the server to gather data from all players.
func carry_player_data_for_all() -> void:
	# Clear any old data first.
	all_players_transition_data.clear()
	
	# Instead of searching the whole tree, we look inside the current level.
	var level = Scene.current_level
	if  not is_instance_valid(level): 
		return
	
	# Find all nodes in the "player" group within the current level.
	for player in level.get_tree().get_nodes_in_group("player"):
		var player_id = int(player.name)
		var data = SaveData.new() # Create a new data container.
		
		# Populate the data from the player's components.
		data.player_stats_data = player.stats_component.stats_data
		data.current_health = player.stats_component.current_health
		data.current_mana = player.stats_component.current_mana
		data.player_inventory_data = player.inventory_component.inventory_data
		data.player_equipment_data = player.equipment_component.equipment_data
		
		# If this player is the one who used the portal, save their target spawn position.
		if player_id == requesting_player_id:
			data.target_spawn_position = target_spawn_position
			
		# Store the populated data in our dictionary.
		all_players_transition_data[player_id] = data
		
func register_player(player_node: Node) -> void:
	var player_id = int(player_node.name)
	
	# REMOVE the 'if not active_players.has(player_id):' check.
	# We MUST always update the dictionary with the newest player instance
	# to overwrite any stale reference from a previous scene.
	active_players[player_id] = player_node
	print("[SERVER] Player %s registered." % player_id)

func unregister_player(player_node: Node) -> void:
	var player_id = int(player_node.name)
	if active_players.has(player_id):
		active_players.erase(player_id)
		print("[SERVER] Player %s unregistered." % player_id)

func get_player(player_id: int) -> Node:
	return active_players.get(player_id, null)

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
