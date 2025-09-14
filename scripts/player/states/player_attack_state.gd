# player_attack_state.gd
# The state for when the player is performing an attack.
class_name PlayerAttackState
extends PlayerState

var target: Node2D # holds the attack target

func enter() -> void:
	print("Player entering Attack State")
	if not is_instance_valid(target):
		# If we enter this state without a valid target, exit immediately.
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
		return
	
	# Tell the component to do its job.
	attack_component.execute(target)
	# Listen for the component to tell us when it's done.
	attack_component.attack_finished.connect(on_attack_finished, CONNECT_ONE_SHOT)

func on_attack_finished() -> void:
	# Once the attack is finished, go back to being idle.
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
 
