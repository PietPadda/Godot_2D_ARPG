# event_bus.gd
## A global singleton for broadcasting game-wide events.
extends Node

# event bus global signals
signal enemy_died(stats_data: CharacterStats, attacker_id: int) # include player's ID
signal game_state_changed(new_state) # This signal is emitted whenever the game state changes.
signal shop_panel_requested # This signal is emitted when any NPC requests a shop panel to be opened.
signal local_player_spawned(player_node) # Player joined annouce with player node reference
# A signal for our server-side debug command to respawn enemies.
signal debug_respawn_enemies_requested
signal server_requesting_transition(scene_path)
# Emitted by an enemy on death, requesting that the level spawn its loot.
signal loot_drop_requested(loot_table: LootTableData, global_position: Vector2)
# NPC range signals
signal player_entered_shop_range
signal player_exited_shop_range
# Emitted by the UI when the player requests to drop an item.
signal item_drop_requested_by_player(item_data: ItemData, global_position: Vector2)

# An Enum provides clear, readable names for our states and prevents errors from typos.
enum GameState {
	GAMEPLAY, # The player has control, game is active.
	UI_MODE   # A UI panel is in control, player input is disabled.
}

# This variable holds the current state of the game.
var current_game_state: GameState = GameState.GAMEPLAY

# A public function that any node can call to change the game state.
func change_game_state(new_state: GameState) -> void:
	if current_game_state == new_state:
		return # Don't do anything if the state isn't actually changing.
	
	current_game_state = new_state
	game_state_changed.emit(current_game_state)
	print("Game state changed to: ", GameState.keys()[new_state])
