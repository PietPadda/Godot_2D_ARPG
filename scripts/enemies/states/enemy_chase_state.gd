# enemy_chase_state.gd
class_name EnemyChaseState
extends PlayerState

var target: Node2D

@onready var owner_node: CharacterBody2D = get_owner()
@onready var attack_component: AttackComponent = owner_node.get_node("AttackComponent")

func enter() -> void:
	print(owner_node.name + " is now Chasing.")

func process_physics(delta: float) -> void:
	# First, check if our target is still valid (hasn't been defeated, etc.).
	if not is_instance_valid(target):
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE]) # change state
		return

	# Continuously update our movement goal to the target's current position.
	movement_component.set_movement_target(target.global_position)

	# Check if we are in range to attack.
	var distance_to_target = owner_node.global_position.distance_to(target.global_position)
	var attack_range = attack_component.get_total_stat("range") # use the total calc, not the base stat!

	if distance_to_target <= attack_range:
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.ATTACK]) # change state
		# Pass the target to the AttackState and transition.
		var attack_state = state_machine.states["attack"]
		attack_state.target = target # Pass the target to the attack state
	else: # not in range yet, must move
		# If not in range, perform movement. This is the missing piece!
		perform_movement()
		
