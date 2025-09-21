# scripts/enemies/states/enemy_state.gd
class_name EnemyState
extends State

# export components
@export var animation_component: AnimationComponent
@export var attack_component: AttackComponent
@export var grid_movement_component: GridMovementComponent
@export var stats_component: StatsComponent

# We can also move shared logic here, like the target validity check.
func is_target_valid(target: Node2D) -> bool:
	return is_instance_valid(target)

func _physics_process(_delta: float) -> void:
	pass
