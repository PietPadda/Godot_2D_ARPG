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

func _ready() -> void:
	# Listen for when the player we control has spawned into a scene.
	EventBus.local_player_spawned.connect(_on_local_player_spawned)

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
