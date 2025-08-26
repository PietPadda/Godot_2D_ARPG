# game_manager.gd
extends Node

const SAVE_PATH = "user://savegame.tres"

# This variable will temporarily hold our loaded data during a scene change.
var loaded_player_data: SaveData = null

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

	var save_data = SaveData.new() # define save data
	save_data.player_stats_data = stats_component.stats_data # update with player stats
	save_data.player_inventory_data = inventory_component.inventory_data # update with player items

	var error = ResourceSaver.save(save_data, SAVE_PATH) # error check
	if error == OK: # will not print if save failed or error occured
		print("Game saved successfully!")

## Load player's game and restart level
func load_game() -> void:
	# check if file actually exists
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found.")
		return

	# Load the data and store it temporarily in our singleton.
	loaded_player_data = ResourceLoader.load(SAVE_PATH)

	# Now, reload the entire level. Diablo 2 style!!
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	print("Game loaded!")
