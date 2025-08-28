# enemy_attack_state.gd
class_name EnemyAttackState
extends State

var target: Node2D

@onready var owner_node: CharacterBody2D = get_owner()
@onready var attack_component: AttackComponent = owner_node.get_node("AttackComponent")
@onready var animation_component: AnimationComponent = owner_node.get_node("AnimationComponent")

func enter() -> void:
	print(owner_node.name + " is now Attacking.")
	if not is_instance_valid(target):
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE]) # change state
		return

	# Stop moving before attacking.
	var movement_component = owner_node.get_node("AIMovementComponent")
	movement_component.set_movement_target(owner_node.global_position)

	# Exceute attacking
	attack_component.execute(target)
	attack_component.attack_finished.connect(on_attack_finished, CONNECT_ONE_SHOT)

func on_attack_finished() -> void:
	# After attacking, go back to chasing the player.
	state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.CHASE]) # change state
