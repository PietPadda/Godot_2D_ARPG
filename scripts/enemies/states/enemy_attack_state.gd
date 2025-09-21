# enemy_attack_state.gd
class_name EnemyAttackState
extends EnemyState # Corrected from State

var target: Node2D

func enter() -> void:
	# Stop all movement before attacking.
	grid_movement_component.stop()
	
	if not is_instance_valid(target):
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE]) # change state
		return

	# Exceute attacking
	attack_component.execute(target)
	attack_component.attack_finished.connect(on_attack_finished, CONNECT_ONE_SHOT)

func _physics_process(_delta: float) -> void:
	pass

func on_attack_finished() -> void:
	# After attacking, decide what to do next.
	if not is_instance_valid(target):
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE])
		return

	# THE FIX: Pass the target back to the Chase state before transitioning.
	var chase_state: EnemyChaseState = state_machine.get_state(States.ENEMY.CHASE)
	if chase_state:
		chase_state.target = target
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.CHASE])
