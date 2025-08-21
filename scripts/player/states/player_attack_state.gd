# player_attack_state.gd
# The state for when the player is performing an attack.
class_name PlayerAttackState
extends State

@onready var player: CharacterBody2D = get_owner()
# We will add this Timer node to our player scene in the next step.
@onready var attack_timer: Timer = get_owner().get_node("AttackTimer")

func enter() -> void:
	# For now, our "attack" is just a print statement.
	# Later, we will use an AttackComponent to handle this.
	print("Player attacks!")

	# Start a timer based on the attack's duration.
	# We don't have the AttackComponent yet, so we'll hardcode 0.5s for now.
	attack_timer.start(0.5)
	# Connect the timer's timeout signal to our state transition method.
	# The CONNECT_ONE_SHOT flag makes it disconnect after one signal.
	attack_timer.timeout.connect(on_attack_finished, CONNECT_ONE_SHOT)

func on_attack_finished() -> void:
	# Once the attack duration is over, return to the Idle state.
	state_machine.change_state("Idle")
