# scripts/enemies/states/enemy_state.gd
class_name EnemyState
extends State

# Common components needed by all enemy states.
@onready var owner_node: CharacterBody2D = get_owner()
@onready var animation_component: AnimationComponent = owner_node.get_node("AnimationComponent")
@onready var stats_component: StatsComponent = owner_node.get_node("StatsComponent")
@onready var attack_component: AttackComponent = owner_node.get_node("AttackComponent")

# We can also move shared logic here, like the target validity check.
func is_target_valid(target: Node2D) -> bool:
	return is_instance_valid(target)
