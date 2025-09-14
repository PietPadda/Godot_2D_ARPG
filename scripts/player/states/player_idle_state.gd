# player_idle_state.gd
# The state for when the player is standing still.
class_name PlayerIdleState
extends PlayerState # Changed from 'State'

func enter() -> void:
		# Explicitly stop all movement when entering the Idle state.
	player.velocity = Vector2.ZERO
	# Play Idle Anim on Entering
	animation_component.play_animation("Idle")
	
	# Connect to the input component's signals when entering the idle state.
	input_component.move_to_requested.connect(_on_move_to_requested)
	input_component.target_requested.connect(_on_target_requested)
	input_component.cast_requested.connect(_on_cast_requested)

func exit() -> void:
	print("Player exiting Idle State")
	# IMPORTANT: Disconnect from the signals when we leave this state to prevent
	# listening for input when we're not supposed to (e.g., while moving or attacking).
	input_component.move_to_requested.disconnect(_on_move_to_requested)
	input_component.target_requested.disconnect(_on_target_requested)
	input_component.cast_requested.disconnect(_on_cast_requested)

# IdleState no longer needs a prcess_input. It doesn't do any input.
func process_input(event: InputEvent) -> void:
	pass
		
# IdleState no longer needs a physics_process. It doesn't do anything continuously.
func _physics_process(_delta: float) -> void:
	pass

# -- Signal Handlers ---
func _on_move_to_requested(target_position: Vector2) -> void:
	var move_state: PlayerMoveState = state_machine.get_state(States.PLAYER.MOVE)
	move_state.destination_tile = Grid.world_to_map(target_position)
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.MOVE])

func _on_target_requested(target: Node2D) -> void:
	var chase_state: PlayerChaseState = state_machine.get_state(States.PLAYER.CHASE)
	chase_state.target = target
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.CHASE])
	
	# Ask the main player node to check the FSM status on the next idle frame.
	# player.call_deferred("check_fsm_status")
