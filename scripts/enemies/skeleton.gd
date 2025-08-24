# skeleton.gd
extends CharacterBody2D

@onready var state_machine: StateMachine = $StateMachine

func _on_aggro_radius_body_entered(body: Node2D) -> void:
	# The body that entered is the player.
	# For now, we'll just print that we see it.
	print("Player detected!")
	# TODO: Transition to ChaseState
