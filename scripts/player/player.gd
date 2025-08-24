# player.gd
extends CharacterBody2D

# get components
@onready var stats_component: StatsComponent = $StatsComponent
@onready var state_machine: StateMachine = $StateMachine

func _ready() -> void:
	# Connect our component's signal to a function in this script.
	stats_component.died.connect(_on_death)

# This function is called when the StatsComponent emits the "died" signal.
func _on_death() -> void:
	# We tell our state machine to switch to the DeadState.
	state_machine.change_state("Dead")
