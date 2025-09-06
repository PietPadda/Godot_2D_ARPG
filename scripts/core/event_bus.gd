# event_bus.gd
## A global singleton for broadcasting game-wide events.
extends Node

# event bus global signals
signal enemy_died(stats_data: CharacterStats)
signal game_state_changed(new_state) # This signal is emitted whenever the game state changes.

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
