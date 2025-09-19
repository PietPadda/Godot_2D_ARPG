# enemy_chase_state.gd
class_name EnemyChaseState
extends EnemyState # Corrected from PlayerState

var target: Node2D
# We no longer need to track the path or last tile here.
# var move_path: PackedVector2Array = [] 
# var last_target_tile: Vector2i

func enter(msg: Dictionary = {}) -> void:
	# The 'target' should be passed in the message dictionary when changing to this state.
	if not msg.has("target") or not is_instance_valid(msg["target"]):
		state_machine.change_state("Idle")
		return
		
	target = msg["target"]
	
	# THE FIX: We connect to 'path_finished'. This is the signal that a complete
	# single-step move has been executed perfectly.
	grid_movement_component.path_finished.connect(_on_path_finished)
	
	_recalculate_path() # Calculate the initial path to get started.

func exit() -> void:
	# CRITICAL: Always disconnect signals when a state exits to avoid unwanted behavior.
	if grid_movement_component.is_connected("path_finished", _on_path_finished):
		grid_movement_component.waypoint_reached.disconnect(_on_path_finished)
	
	grid_movement_component.stop()
	
# THE FIX: We remove the logic from _physics_process. Decisions should not be made
# every frame, only after a move is complete.
func _physics_process(_delta: float) -> void:
	# We still need to check if our target has disappeared.
	if not is_instance_valid(target):
		state_machine.change_state("Idle")
		return
		
# This is now the main driver of our AI loop. It runs AFTER a move is complete.
func _on_path_finished() -> void:
	if not is_instance_valid(target):
		state_machine.change_state("Idle")
		return

	# Check for attack range now that we are centered on a tile.
	var attack_range = stats_component.get_total_stat("range")
	if owner.global_position.distance_to(target.global_position) <= attack_range:
		# We are in range, so transition to the Attack state.
		# We pass the target to the attack state.
		state_machine.change_state("Attack", { "target": target })
		return

	# If we're not in attack range, request the next step of the path.
	_recalculate_path()

# Calculates a new path request.
func _recalculate_path() -> void:
	# Ensure target is still valid before trying to pathfind to it.
	if not is_instance_valid(target):
		return
	
	var start = Grid.world_to_map(owner_node.global_position)
	var end = Grid.world_to_map(target.global_position)
	
	# Enemies also use the new unified request system.
	Grid.request_path(start, end, owner)
