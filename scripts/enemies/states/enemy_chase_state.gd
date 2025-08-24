# enemy_chase_state.gd
class_name EnemyChaseState
extends State

var target: Node2D

@onready var owner_node: CharacterBody2D = get_owner()
@onready var movement_component: MovementComponent = owner_node.get_node("MovementComponent")

func enter() -> void:
	print(owner_node.name + " is now Chasing.")

func process_physics(delta: float) -> void:
	# First, check if our target is still valid (hasn't been defeated, etc.).
	if not is_instance_valid(target):
		state_machine.change_state("Idle")
		return

	# Continuously update our movement goal to the target's current position.
	movement_component.set_movement_target(target.global_position)

	# In the next step, we will add a check here to see if we're in attack range.
