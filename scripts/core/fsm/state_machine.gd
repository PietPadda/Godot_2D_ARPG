# state_machine.gd
# Manages a set of states and handles transitions between them.
class_name StateMachine
extends Node

# The state to start in. We'll set this in the editor.
@export var initial_state: State

# A dictionary to hold references to all available state nodes.
var states: Dictionary = {}
# The currently active state.
var current_state: State

func _ready() -> void:
	# Find all child nodes that are States and add them to our dictionary.
	for child in get_children(): # all children of the state machine in scene
		if child is State:
			states[child.name.to_lower()] = child # lc to compare easy
			# We also need to provide each state with a reference back to this machine.
			child.state_machine = self

	# Ensure an initial state has been set in the editor.
	if not initial_state:
		push_warning("StateMachine needs an initial_state to be set.")
		return
	
	# Enter the initial state.
	current_state = initial_state
	current_state.enter()

func _unhandled_input(event: InputEvent) -> void:
	# Delegate input processing to the active state.
	if current_state:
		current_state.process_input(event)

func _physics_process(delta: float) -> void:
	# Delegate physics processing to the active state.
	if current_state:
		current_state.process_physics(delta)

# The main function for changing states.
func change_state(new_state_name: String) -> void:
	var new_state = states.get(new_state_name.to_lower())
	if not new_state: # edge case if not a valid state
		push_warning("StateMachine does not have a state named: %s" % new_state_name)
		return
	if new_state == current_state:
		return

	# Call the exit logic on the old state, switch, and call enter on the new one.
	if current_state:
		current_state.exit()
	
	current_state = new_state
	current_state.enter()
