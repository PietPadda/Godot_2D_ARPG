# enemy_attack_state.gd
class_name EnemyAttackState
extends EnemyState # Corrected from State

var target: Node2D

# Component references are now inherited.

func enter() -> void:
	print(owner_node.name + " is now Attacking.")
	if not is_instance_valid(target):
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE]) # change state
		return

	# Stop moving before attacking.
	movement_component.set_movement_target(owner_node.global_position)

	# Exceute attacking
	attack_component.execute(target)
	attack_component.attack_finished.connect(on_attack_finished, CONNECT_ONE_SHOT)

func on_attack_finished() -> void:
	# After attacking, go back to chasing the player.
	state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.CHASE]) # change state
