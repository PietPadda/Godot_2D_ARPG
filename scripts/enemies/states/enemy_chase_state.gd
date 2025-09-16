# enemy_chase_state.gd
class_name EnemyChaseState
extends EnemyState # Corrected from PlayerState

var target: Node2D
var move_path: PackedVector2Array = []
var last_target_tile: Vector2i

func enter() -> void:
	if not is_instance_valid(target):
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE])
		return
		
	# Connect the signal. Every time the component reaches a waypoint, we'll recalculate the path.
	# This makes the AI much more reactive to a changing environment.
	grid_movement_component.waypoint_reached.connect(_recalculate_path)
	
	_recalculate_path() # Calculate the initial path to get started.

func exit() -> void:
	# CRITICAL: Always disconnect signals when a state exits to avoid unwanted behavior.
	if grid_movement_component.is_connected("waypoint_reached", _recalculate_path):
		grid_movement_component.waypoint_reached.disconnect(_recalculate_path)
	
	grid_movement_component.stop()
	
func _physics_process(delta: float) -> void:
	# First, check if our target is still valid (hasn't been defeated, etc.).
	if not is_instance_valid(target): # Use the shared function from the base class
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE]) # change state
		return

	# First, check if we are in range to attack.
	var distance = owner_node.global_position.distance_to(target.global_position)
	if distance <= stats_component.get_total_stat("range"):
		var attack_state: EnemyAttackState = state_machine.get_state(States.ENEMY.ATTACK)
		attack_state.target = target
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.ATTACK])
		return

	# If not in range, check if we need to find a new path.
	if not grid_movement_component.is_moving:
		var current_target_tile = Grid.world_to_map(target.global_position)
		if current_target_tile != last_target_tile:
			_recalculate_path()

# Calculates a new path and tells the component to start moving.
func _recalculate_path() -> void:
	var start = Grid.world_to_map(owner_node.global_position)
	var end = Grid.world_to_map(target.global_position)
	last_target_tile = end
	
	# THE FIX: Enemies also use the new unified request system.
	Grid.request_path(start, end, owner_node)
