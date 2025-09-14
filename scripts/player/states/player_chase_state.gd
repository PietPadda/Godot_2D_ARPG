# player_chase_state.gd
# The state for moving towards a target to get within attack range.
class_name PlayerChaseState
extends PlayerState # Make sure it extends PlayerState

var target: Node2D
# We need to track the target's last known tile to avoid spamming the pathfinder.
var last_target_tile: Vector2i

func enter() -> void:
	# On entering, immediately start moving towards the target.
	if not is_instance_valid(target):
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE]) # just idle if invalid target
		return # early exit
	
	player.get_node("AnimationComponent").play_animation("Move")
	
	# Connect to ALL necessary signals for responsive control.
	grid_movement_component.path_finished.connect(_on_path_finished) # Key change!
	# these connections allow the player to interrupt the chase.
	input_component.move_to_requested.connect(_on_move_to_requested)
	input_component.target_requested.connect(_on_target_requested)
	input_component.cast_requested.connect(_on_cast_requested)
	
	_recalculate_path() # Start the chase

func exit() -> void:
	# Disconnect from all signals for clean state transitions
	# This was trying to disconnect the wrong function (_recalculate_path).
	# It should be disconnecting the one we connected in enter(): _on_path_finished.
	if grid_movement_component.path_finished.is_connected(_on_path_finished):
		grid_movement_component.path_finished.disconnect(_on_path_finished)
	if input_component.move_to_requested.is_connected(_on_move_to_requested):
		input_component.move_to_requested.disconnect(_on_move_to_requested)
	if input_component.target_requested.is_connected(_on_target_requested):
		input_component.target_requested.disconnect(_on_target_requested)
	if input_component.cast_requested.is_connected(_on_cast_requested):
		input_component.cast_requested.disconnect(_on_cast_requested)

	# Crucial cleanup to stop movement when exiting the state.
	grid_movement_component.stop()

func _process_physics(delta: float) -> void:
	# First, check if our target still exists.
	if not is_instance_valid(target):
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE]) # just idle if invalid target
		return # early exit
	
	var distance = player.global_position.distance_to(target.global_position)
	var attack_range = stats_component.get_total_stat("range")

	# THE FIX: This is now our highest priority, checked every frame.
	# Are we within attack range RIGHT NOW?
	if distance <= attack_range:
		print("[ChaseState] Target in range! Stopping movement and switching to Attack.")
		grid_movement_component.stop() # Immediately stop all movement.
		var attack_state: PlayerAttackState = state_machine.get_state(States.PLAYER.ATTACK)
		attack_state.target = target
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.ATTACK])
		return # Our job in this state is done.

	# If we are NOT in attack range, then we continue with our movement logic.
	# Check if the target has moved to a new tile, requiring a new path.
	var current_target_tile = Grid.world_to_map(target.global_position)
	if current_target_tile != last_target_tile:
		_recalculate_path()

# --- Helper Functions ---
# Gets a new path and starts the movement process.
func _recalculate_path() -> void:
	if not is_instance_valid(target): 
		return
	var start_pos = Grid.world_to_map(player.global_position)
	var end_pos = Grid.world_to_map(target.global_position)
	
	# Find a valid, unoccupied adjacent tile to the target
	var destination_found = false
	var valid_destination: Vector2i
	
	for tile in Grid.get_adjacent_tiles(end_pos):
		if Grid.is_tile_vacant(tile):
			valid_destination = tile
			destination_found = true
			break
			
	# If we found a valid destination, move there
	if destination_found:
		# generate the path
		last_target_tile = valid_destination
		var path = Grid.find_path(start_pos, valid_destination)
		
		# The state simply tells the component what path to follow.
		if not path.is_empty():
			# Pass the actual target to the movement component.
			grid_movement_component.move_along_path(path, target)

# --- Signal Handlers ---
func _on_move_to_requested(target_position: Vector2) -> void:
	var move_state: PlayerMoveState = state_machine.get_state(States.PLAYER.MOVE)
	move_state.destination_tile = Grid.world_to_map(target_position)
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.MOVE])
	
func _on_path_finished():
	# If the path finishes and we are STILL not in range (checked by _process_physics),
	# it means the target has moved. We should try to find a new path.
	# We'll add a validity check here as a safeguard.
	if is_instance_valid(target):
		_recalculate_path()
	else:
		# If the target is gone, just go idle.
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])

func _on_target_requested(new_target: Node2D) -> void:
	if new_target != self.target:
		self.target = new_target
		_recalculate_path() # Immediately repath to the new target
