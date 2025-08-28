# enemy_chase_state.gd
class_name EnemyChaseState
extends EnemyState # Corrected from PlayerState

var target: Node2D

# All @onready vars are now inherited from EnemyState, so we can remove them.

func enter() -> void:
	print(owner_node.name + " is now Chasing.")

func process_physics(delta: float) -> void:
	# First, check if our target is still valid (hasn't been defeated, etc.).
	if not is_instance_valid(target): # Use the shared function from the base class
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE]) # change state
		return

	# Continuously update our movement goal to the target's current position.
	movement_component.set_movement_target(target.global_position)

	# Check if we are in range to attack.
	var distance_to_target = owner_node.global_position.distance_to(target.global_position)
	var attack_range = attack_component.get_total_stat("range") # use the total calc, not the base stat!

	if distance_to_target <= attack_range:
				# Pass the target to the AttackState and transition.
		var attack_state = state_machine.states["attack"]
		attack_state.target = target # Pass the target to the attack state
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.ATTACK]) # change state
	# We don't need an 'else' block to call movement here, because the AIMovementComponent
	# is always running its own _physics_process to move the character.
