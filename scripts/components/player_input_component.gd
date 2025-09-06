# scripts/components/player_input_component.gd

# This component captures raw player input and translates it into game-specific
# commands, broadcasting them via signals. It acts as the bridge between player
# hardware and the character's FSM.
class_name PlayerInputComponent
extends Node

# --- Signals ---
signal move_to_requested(target_position: Vector2)
signal target_requested(target: Node2D)

# --- Scene Nodes ---
@onready var targeting_component: PlayerTargetingComponent = get_parent().get_node("PlayerTargetingComponent")

func _unhandled_input(event: InputEvent) -> void:
	# Only process input if the game is in a state that allows it.
	if EventBus.current_game_state != EventBus.GameState.GAMEPLAY:
		return

	if event.is_action_pressed("move_click"):
		var target = targeting_component.get_target_under_mouse()
		if is_instance_valid(target):
			# An enemy or interactable was clicked.
			target_requested.emit(target)
		else:
			# The ground was clicked. We get the position from the event itself,
			# as InputEventMouseButton contains a 'global_position' property.
			move_to_requested.emit(event.global_position)
