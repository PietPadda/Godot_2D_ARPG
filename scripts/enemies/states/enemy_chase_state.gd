# enemy_chase_state.gd
class_name EnemyChaseState
extends EnemyState # Corrected from PlayerState

var target: Node2D

func enter(msg: Dictionary = {}) -> void:
	# Use the robust 'msg' dictionary to get the target.
	if not msg.has("target") or not is_instance_valid(msg["target"]):
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE])
		return
	target = msg["target"]
		
	# We no longer need to connect to any signals for our main AI loop.
	_recalculate_path()

func exit() -> void:
	# No signals to disconnect.
	grid_movement_component.stop()
	
func _physics_process(_delta: float) -> void:
	# First, always check if our target is valid.
	if not is_instance_valid(target):
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE]) # change state
		return

	# THE FINAL FIX: This is now our main AI loop.
	# We only run our logic if we are NOT currently in the middle of a move.
	if not grid_movement_component.is_moving:
		# Check for attack range. This is now safe because we are stationary.
		# This guarantees the check only happens when we are perfectly centered.
		var distance = owner_node.global_position.distance_to(target.global_position)
		if distance <= stats_component.get_total_stat("range"):
			# Use get_state() with the ENUM to get a reference.
			var attack_state: EnemyAttackState = state_machine.get_state(States.ENEMY.ATTACK)
			if attack_state:
				# Set the target property directly on that state.
				attack_state.target = target
				# We're in range, so switch to the Attack state.
				state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.ATTACK]) # change state
			return # Exit physics process for this frame.ve.
		
		# If not in range, recalculate our next step.
		_recalculate_path()

# This function is now just a helper for requesting a path.
func _recalculate_path() -> void:
	if not is_instance_valid(target):
		return

	# If not in range, then proceed with finding the next step.
	var start = Grid.world_to_map(owner_node.global_position)
	var end = Grid.world_to_map(target.global_position)
	
	# Enemies also use the new unified request system.
	Grid.request_path(start, end, owner_node)
