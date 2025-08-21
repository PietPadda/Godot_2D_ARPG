# player_attack_state.gd
# The state for when the player is performing an attack.
class_name PlayerAttackState
extends State

# A reference to the AttackComponent.
@onready var attack_component: AttackComponent = get_owner().get_node("AttackComponent")

func enter() -> void:
	# Tell the component to do its job.
	attack_component.execute()
	# Listen for the component to tell us when it's done.
	attack_component.attack_finished.connect(on_attack_finished, CONNECT_ONE_SHOT)

func on_attack_finished() -> void:
	# Once the attack is finished, go back to being idle.
	state_machine.change_state("Idle")
 
