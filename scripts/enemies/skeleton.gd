# skeleton.gd
extends CharacterBody2D

@onready var state_machine: StateMachine = $StateMachine
@onready var stats_component: StatsComponent = $StatsComponent
@onready var loot_component: LootComponent = $LootComponent
@onready var health_bar = $HealthBar
@onready var raycast: RayCast2D = $RayCast2D

# We need a reference to the player. We'll get it from the chase state.
var current_target: Node2D

func _ready() -> void:
	# connect signals to functions
	stats_component.died.connect(_on_death)
	
func _on_aggro_radius_body_entered(body: Node2D) -> void:
	# Don't re-aggro if we're already chasing or attacking.
	if state_machine.current_state.name != "Idle":
		return
	
	current_target = body # Store the target here.
	
	# Get the Chase state, give it the player as a target, and change state.
	var chase_state = state_machine.states["chase"] # set state var
	chase_state.target = body # set state target
	state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.CHASE]) # update state
	
# We will use _physics_process to keep the UI in sync with the data.
# This is now the ONLY logic that controls the health bar.
func _physics_process(_delta):
	# Constantly update the health bar with the latest synced value.
	if stats_component and health_bar:
		# Read directly from the now-synced StatsComponent.
		var current = stats_component.current_health
		var max_val = stats_component.stats_data.max_health
		health_bar.update_health(current, max_val)
		health_bar.visible = (current < max_val)
	
	 # Line-of-sight logic
	if is_instance_valid(current_target):
		# Point the ray from our position to the target's position.
		raycast.target_position = current_target.global_position - global_position

		# Force the ray to update its collision status immediately.
		raycast.force_raycast_update()

		# Check the result.
		if raycast.is_colliding():
			# The ray hit a wall before it hit the player. Hide.
			hide()
		else:
			# The path is clear. Show.
			show()
	else:
		# If we have no target, we should be hidden by default.
		hide()
	
# This function is called when our own StatsComponent emits the "died" signal.
func _on_death(attacker_id: int) -> void:
	# Announce the death and pass along our stats data.
	EventBus.emit_signal("enemy_died", stats_component.stats_data, attacker_id)
	# Tell the engine to call our new function, but only after the physics step is complete.
	call_deferred("_spawn_loot_and_die")

# This new function contains the logic that modifies the scene tree.
func _spawn_loot_and_die():
	# Tell the LootComponent to handle the drop at our current position.
	loot_component.drop_loot(global_position)
	
	# We explicitly tell the GridManager to remove us before we delete ourselves.
	# Only the machine with authority over the skeleton should send this RPC.
	if is_multiplayer_authority():
		Grid.clear_character_from_grid.rpc_id(1, get_path())
		
	# When this enemy dies, it should remove itself from the game.
	queue_free()
