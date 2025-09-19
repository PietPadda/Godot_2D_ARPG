# enemy_chase_state.gd
class_name EnemyChaseState
extends EnemyState # Corrected from PlayerState

var target: Node2D
var last_target_tile: Vector2i

func enter(msg: Dictionary = {}) -> void:
	# Use the robust 'msg' dictionary to get the target.
	if not msg.has("target") or not is_instance_valid(msg["target"]):
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE])
		return
	target = msg["target"]
		
	# Connect to 'path_finished' - the correct signal for our single-step system.
	grid_movement_component.path_finished.connect(_recalculate_path)
	
	_recalculate_path() # Start the loop.

func exit() -> void:
	# Correctly disconnect the 'path_finished' signal.
	if grid_movement_component.is_connected("path_finished", _recalculate_path):
		grid_movement_component.path_finished.disconnect(_recalculate_path)
	
	grid_movement_component.stop()
	
func _physics_process(_delta: float) -> void:
	# We only need to check if our target has disappeared.
	if not is_instance_valid(target):
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE]) # change state
		return

	# If the enemy gets stuck, this is a fallback to try moving again if the player moves.
	if not grid_movement_component.is_moving:
		var current_target_tile = Grid.world_to_map(target.global_position)
		if current_target_tile != last_target_tile:
			_recalculate_path()

# This function is now the complete driver for the AI's chase logic.
func _recalculate_path() -> void:
	if not is_instance_valid(target):
		return
		
	# THE FIX: Check for attack range HERE, before pathfinding.
	# This guarantees the check only happens when we are perfectly centered.
	var distance = owner_node.global_position.distance_to(target.global_position)
	if distance <= stats_component.get_total_stat("range"):
		# THE FIX: Use get_state() with the ENUM to get a reference.
		var attack_state: EnemyAttackState = state_machine.get_state(States.ENEMY.ATTACK)
		if attack_state:
			# Set the target property directly on that state.
			attack_state.target = target
			# We're in range, so switch to the Attack state.
			state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.ATTACK]) # change state
		return # Stop here, we don't need to move.
	
	# If not in range, then proceed with finding the next step.
	var start = Grid.world_to_map(owner_node.global_position)
	var end = Grid.world_to_map(target.global_position)
	last_target_tile = end
	
	# Enemies also use the new unified request system.
	Grid.request_path(start, end, owner_node)
