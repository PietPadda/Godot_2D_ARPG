# player.gd
extends CharacterBody2D

# preload scenes to instance
const GameOverScreen = preload("res://scenes/ui/game_over_screen.tscn")

# get components
@onready var stats_component: StatsComponent = $StatsComponent
@onready var state_machine: StateMachine = $StateMachine

func _ready() -> void:
	# Check for SAVE GAME data first (highest priority).
	if is_instance_valid(GameManager.loaded_player_data):
		print("Applying loaded data to player...")
		# Swap our default resources with the loaded ones.
		stats_component.stats_data = GameManager.loaded_player_data.player_stats_data
		# Apply the loaded inventory data
		var inventory_component = get_node("InventoryComponent")
		inventory_component.inventory_data = GameManager.loaded_player_data.player_inventory_data
		# Apply the loaded equipment data
		var equipment_component = get_node("EquipmentComponent")
		equipment_component.equipment_data = GameManager.loaded_player_data.player_equipment_data
		
		# On SAVE LOAD, restore to full health and mana (Diablo II style).
		stats_component.current_health = stats_component.stats_data.max_health
		stats_component.current_mana = stats_component.stats_data.max_mana

		# Tell the UI to update.
		stats_component.refresh_stats()

		# Clear the data from the manager so it's not reused.
		GameManager.loaded_player_data = null
		
		# We need to manually tell the UI to redraw after loading all the data
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.character_sheet:
			hud.character_sheet.redraw()
			
	# If not loading a save, check for TRANSITION data.
	elif is_instance_valid(GameManager.player_data_on_transition):
		print("Applying transitioned data to player...")
		var transition_data = GameManager.player_data_on_transition
		stats_component.stats_data = transition_data.player_stats_data
		get_node("InventoryComponent").inventory_data = transition_data.player_inventory_data
		get_node("EquipmentComponent").equipment_data = transition_data.player_equipment_data
		
		# Check if a target spawn position was carried over.
		if transition_data.target_spawn_position != Vector2.INF:
			# Use call_deferred to wait for the physics engine to settle.
			call_deferred("set_global_position", transition_data.target_spawn_position)
		
		# On SCENE TRANSITION, apply the carried-over health and mana.
		stats_component.current_health = transition_data.current_health
		stats_component.current_mana = transition_data.current_mana
		
		# Tell the UI to update.
		stats_component.refresh_stats()
		
		# Clear the transition data from the manager so it's not reused.
		GameManager.player_data_on_transition = null
	
	# Connect our component's signal to a function in this script.
	stats_component.died.connect(_on_death) # player died
	EventBus.enemy_died.connect(_on_enemy_died) # enemy died

# This function is called when the StatsComponent emits the "died" signal.
## Player death function for Player
func _on_death() -> void:
	# We tell our state machine to switch to the DeadState.
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.DEAD])
	
	# Create an instance of our Game Over screen.
	var game_over_instance = GameOverScreen.instantiate()
	# Add it to the parent (level) scene tree.
	get_tree().current_scene.add_child(game_over_instance)

## Enemy died function for Player
func _on_enemy_died(enemy_stats_data: CharacterStats) -> void:
	# When an enemy dies, add its XP reward to our stats.
	stats_component.add_xp(enemy_stats_data.xp_reward)
