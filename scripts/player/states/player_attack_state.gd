# player_attack_state.gd
# The state for when the player is performing an attack.
class_name PlayerAttackState
extends State

var target: Node2D # holds the attack target

# A reference to the AttackComponent.
@onready var attack_component: AttackComponent = get_owner().get_node("AttackComponent")
@onready var animation_component: AnimationComponent = get_owner().get_node("AnimationComponent")

func enter() -> void:
	print("Entering Attack State")
	if not is_instance_valid(target):
		# If we enter this state without a valid target, exit immediately.
		state_machine.change_state("Idle")
		return
	
	# Tell the component to do its job.
	attack_component.execute(target)
	# Listen for the component to tell us when it's done.
	attack_component.attack_finished.connect(on_attack_finished, CONNECT_ONE_SHOT)

func on_attack_finished() -> void:
	print("Exiting Attack State")
	# Once the attack is finished, go back to being idle.
	state_machine.change_state("Idle")
 
