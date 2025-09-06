# scripts/enemies/states/enemy_state.gd
class_name EnemyState
extends State

# Common components needed by all enemy states.
@onready var owner_node: CharacterBody2D = get_owner()

# export components
@export var animation_component: AnimationComponent
@export var stats_component: StatsComponent
@export var attack_component: AttackComponent

# We can also move shared logic here, like the target validity check.
func is_target_valid(target: Node2D) -> bool:
	return is_instance_valid(target)
