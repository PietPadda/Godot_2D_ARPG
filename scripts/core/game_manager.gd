# game_manager.gd
extends Node

const SAVE_PATH = "user://savegame.tres"

# This variable will temporarily hold our loaded data during a scene change.
var loaded_player_data: SaveData = null
# This variable will hold our player's data during a normal scene transition.
var player_data_on_transition: SaveData = null

# --- Public API ---

#  This function grabs the current player's data and stores it for the transition.
## Save chardata between scene transitions
func carry_player_data() -> void:
	var player = get_tree().get_first_node_in_group("player") # get player
	if not player:
		push_error("GameManager: Could not find player to carry data.")
		return
	
	# We create a new SaveData resource to hold the current data.
	# We use .duplicate() to ensure it's a unique copy.
	var current_data = SaveData.new()
	current_data.player_stats_data = player.get_node("StatsComponent").stats_data.duplicate(true)
	current_data.player_inventory_data = player.get_node("InventoryComponent").inventory_data.duplicate(true)
	current_data.player_equipment_data = player.get_node("EquipmentComponent").equipment_data.duplicate(true)
	
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
		
	# Now, reload the entire level. Diablo 2 style!!
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	print("Game loaded!")
