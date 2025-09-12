# scripts/components/player_input_component.gd

# This component captures raw player input and translates it into game-specific
# commands, broadcasting them via signals. It acts as the bridge between player
# hardware and the character's FSM.
class_name PlayerInputComponent
extends Node

# --- Signals ---
signal move_to_requested(target_position: Vector2)
signal target_requested(target: Node2D)
signal cast_requested(skill_slot: int, target_position: Vector2)

# --- Scene Nodes ---
@onready var targeting_component: PlayerTargetingComponent = get_parent().get_node("PlayerTargetingComponent")

func _unhandled_input(event: InputEvent) -> void:
	# Only process input if this client has authority over the player character.
	# The Player node is the parent of this component.
	if not get_parent().is_multiplayer_authority():
		return # If not the authority, stop right here.
		
	# Only process input if the game is in a state that allows it.
	if EventBus.current_game_state != EventBus.GameState.GAMEPLAY:
		return
		
	# We only care about the initial press of an action in this function.
	if not event.is_pressed():
		return

	if event.is_action("move_click"):
		# This is the single, correct block for handling the move_click action.
		var mouse_pos = get_parent().get_global_mouse_position()
		var target = targeting_component.get_target_under_mouse()
		if is_instance_valid(target):
			# An enemy or interactable was clicked.
			target_requested.emit(target)
		else:
			move_to_requested.emit(mouse_pos)
			
	# logic for handling the cast action
	if event.is_action_pressed("cast_skill") and event is InputEventMouseButton:
		# Use the same reliable source for the cast position.
		var mouse_pos = get_parent().get_global_mouse_position()
		cast_requested.emit(States.SkillSlots.SECONDARY, mouse_pos)

# We add _physics_process for continuous actions, like holding a button down.
# _unhandled_input is better for discrete, single-press events.
func _physics_process(_delta: float) -> void:
	# Only process input if this client has authority over the player character.
	# The Player node is the parent of this component.
	if not get_parent().is_multiplayer_authority():
		return # If not the authority, stop right here.
	
	if EventBus.current_game_state != EventBus.GameState.GAMEPLAY:
		return

	# If the move action is held down, continuously broadcast the intention to move.
	if Input.is_action_pressed("move_click"):
		# Check for a target first, just like in _unhandled_input.
		var target = targeting_component.get_target_under_mouse()
		if is_instance_valid(target):
			# If holding on a target, keep emitting the target request.
			target_requested.emit(target)
		else:
			# If holding on the ground, emit a move request.
			move_to_requested.emit(get_parent().get_global_mouse_position())
