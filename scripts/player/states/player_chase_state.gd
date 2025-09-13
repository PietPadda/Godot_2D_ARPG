# player_chase_state.gd
# The state for moving towards a target to get within attack range.
class_name PlayerChaseState
extends PlayerState # Make sure it extends PlayerState

var target: Node2D
# We need to track the target's last known tile to avoid spamming the pathfinder.
var last_target_tile: Vector2i
# Stack trace counter
var recalculate_counter = 0

func enter() -> void:
	print("ENTERING CHASE STATE!")
	# On entering, immediately start moving towards the target.
	if not is_instance_valid(target):
		print("INVALID CHASE TARGET!")
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE]) # just idle if invalid target
		return # early exit
	
	print("VALID CHASE TARGET!")
	player.get_node("AnimationComponent").play_animation("Move")
	
	# Connect to signals for interruption and movement logic
	# REMOVE THIS LINE: The chase state doesn't need to handle being stuck.
	# grid_movement_component.path_stuck.connect(_recalculate_path) 
	input_component.move_to_requested.connect(_on_move_to_requested)
	input_component.target_requested.connect(_on_target_requested)
	input_component.cast_requested.connect(_on_cast_requested)
	print("RECALC CHASE PATH!")
	_recalculate_path() # Start the chase

func exit() -> void:
	print("EXITING CHASE STATE!")
	# REMOVE THIS BLOCK: We no longer need to disconnect from a signal we're not connected to.
	# if grid_movement_component.path_stuck.is_connected(_recalculate_path):
	# 	grid_movement_component.path_stuck.disconnect(_recalculate_path)
	input_component.move_to_requested.disconnect(_on_move_to_requested)
	input_component.target_requested.disconnect(_on_target_requested)
	input_component.cast_requested.disconnect(_on_cast_requested)
	
	# Crucial cleanup to stop movement when exiting the state.
	grid_movement_component.stop()

func _process_physics(delta: float) -> void:
	print("ENTERING CHASE STATE PROCESS PHYSICS!")
	# First, check if our target still exists.
	if not is_instance_valid(target):
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE]) # just idle if invalid target
		return # early exit

	# First, always check if we've arrived in attack range.
	var distance = player.global_position.distance_to(target.global_position) 
	var attack_range = stats_component.get_total_stat("range")
	
	# --- NEW DEBUG PRINTS ---
	# Let's see what the actual values are every frame.
	print("Distance to Target: ", distance, " | Attack Range: ", attack_range)
	# --- END DEBUG PRINTS ---

	if distance <= attack_range:
		var attack_state: PlayerAttackState = state_machine.get_state(States.PLAYER.ATTACK)
		attack_state.target = target
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.ATTACK])
		return
	
	# Only recalculate if the target has moved to a new tile.
	var current_target_tile = Grid.world_to_map(target.global_position)
	if current_target_tile != last_target_tile:
		_recalculate_path()

# --- Helper Functions ---
# Gets a new path and starts the movement process.
func _recalculate_path() -> void:
	print("ENTERING CHASE STATE RECALC PATH!")
	# Add a counter to prevent the game from freezing from too many prints.
	if recalculate_counter > 5:
		return
	recalculate_counter += 1
	
	# THE DEBUG STEP: Print the function call stack.
	print("--- STACK TRACE FOR _recalculate_path ---")
	print_stack()
	
	if not is_instance_valid(target): 
		print("INVALID RECALC PATH TARGET!")
		return
	print("VALID RECALC PATH TARGET!")
	var start_pos = Grid.world_to_map(player.global_position)
	var end_pos = Grid.world_to_map(target.global_position)
	
	last_target_tile = end_pos
	var path = Grid.find_path(start_pos, end_pos)
	
	# The state simply tells the component what path to follow.
	if not path.is_empty():
		print("CHASE STATE MOVE ALONG PATH!")
		grid_movement_component.move_along_path(path)

# --- Signal Handlers ---
func _on_move_to_requested(target_position: Vector2) -> void:
	var move_state: PlayerMoveState = state_machine.get_state(States.PLAYER.MOVE)
	move_state.destination_tile = Grid.world_to_map(target_position)
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.MOVE])

func _on_target_requested(new_target: Node2D) -> void:
	if new_target != self.target:
		self.target = new_target
		_recalculate_path() # Immediately repath to the new target
