# state.gd
# The base class for all states in the FSM. It defines the "contract" or
# interface that all states must follow. It is not used directly.
class_name State
extends Node

# A reference to the state machine that owns this state.
var state_machine: Node

# Virtual function. Called by the state machine when entering this state.
func enter() -> void:
	pass

# Virtual function. Called by the state machine when exiting this state.
func exit() -> void:
	pass

# Virtual function. Called every frame. Use for non-physics logic.
func process_input(event: InputEvent) -> void:
	pass

# Virtual function. Called every physics frame. Use for physics logic.
func process_physics(delta: float) -> void:
	pass
