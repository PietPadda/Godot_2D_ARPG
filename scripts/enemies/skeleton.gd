# skeleton.gd
extends CharacterBody2D

@onready var state_machine: StateMachine = $StateMachine
@onready var stats_component: StatsComponent = $StatsComponent
@onready var health_bar = $HealthBar

func _ready() -> void:
	# connect signals to functions
	stats_component.health_changed.connect(health_bar.update_health)
	stats_component.died.connect(_on_death)

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
	
# This function is called when our own StatsComponent emits the "died" signal.
func _on_death() -> void:
	# When this enemy dies, it should remove itself from the game.
	queue_free()
