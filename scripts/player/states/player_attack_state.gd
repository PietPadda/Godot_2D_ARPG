# player_attack_state.gd
# The state for when the player is performing an attack.
class_name PlayerAttackState
extends PlayerState

var target: Node2D # holds the attack target

func enter() -> void:
	if not is_instance_valid(target):
		# If we enter this state without a valid target, exit immediately.
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
		return
	
	# Tell the component to do its job.
	attack_component.execute(target)
	# Listen for the component to tell us when it's done.
	attack_component.attack_finished.connect(on_attack_finished) # No longer one-shot

#  We add an exit() function to clean up our signal connection.
func exit() -> void:
	# This ensures that every time we leave the AttackState, the connection is removed.
	if attack_component.attack_finished.is_connected(on_attack_finished):
		attack_component.attack_finished.disconnect(on_attack_finished)

func _physics_process(delta: float) -> void:
	pass

func on_attack_finished() -> void:
	# Once the attack is finished, go back to being idle.
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
 
