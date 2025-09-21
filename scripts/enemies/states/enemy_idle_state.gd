# enemy_idle_state.gd
class_name EnemyIdleState
extends EnemyState # Corrected from State

# No @onready needed, owner_node is inherited.

func enter() -> void:
	pass
	
func _physics_process(_delta: float) -> void:
	pass
