# enemy_idle_state.gd
class_name EnemyIdleState
extends State

func enter() -> void:
	print(get_owner().name + " is now Idle.")
