# skeleton.gd
extends CharacterBody2D

@onready var state_machine: StateMachine = $StateMachine
@onready var stats_component: StatsComponent = $StatsComponent
@onready var health_bar = $HealthBar

func _ready() -> void:
	# Connect the stats signal to the health bar's update function
	stats_component.health_changed.connect(health_bar.update_health)

func _on_aggro_radius_body_entered(body: Node2D) -> void:
	# Don't re-aggro if we're already chasing or attacking.
	if state_machine.current_state.name != "Idle":
		return
		
	# The body that entered is the player.
	print("Player detected! Giving chase.")
	
	# Get the Chase state, give it the player as a target, and change state.
	var chase_state = state_machine.states["chase"] # set state var
	chase_state.target = body # set state target
	state_machine.change_state("Chase") # update state
