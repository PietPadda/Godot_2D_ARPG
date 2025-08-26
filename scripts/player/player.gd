# player.gd
extends CharacterBody2D

# preload scenes to instance
const GameOverScreen = preload("res://scenes/ui/game_over_screen.tscn")

# get components
@onready var stats_component: StatsComponent = $StatsComponent
@onready var state_machine: StateMachine = $StateMachine

func _ready() -> void:
	# If loading a save game
	if GameManager.loaded_player_data:
		print("Applying loaded data to player...")
		# Swap our default resources with the loaded ones.
		stats_component.stats_data = GameManager.loaded_player_data.player_stats_data
		var inventory_component = get_node("InventoryComponent")
		inventory_component.inventory_data = GameManager.loaded_player_data.player_inventory_data

		# Manually update current health/mana from the loaded data.
		stats_component.current_health = stats_component.stats_data.max_health
		stats_component.current_mana = stats_component.stats_data.max_mana

		# Tell the UI to update.
		stats_component.refresh_stats()

		# Clear the data from the manager so it's not reused.
		GameManager.loaded_player_data = null
	
	# Connect our component's signal to a function in this script.
	stats_component.died.connect(_on_death) # player died
	EventBus.enemy_died.connect(_on_enemy_died) # enemy died
	
	# TEMPORARY: Equip a sword at the start of the game for testing.
	get_node("EquipmentComponent").equip_item(load("res://data/items/crude_sword.tres"))

# This function is called when the StatsComponent emits the "died" signal.
## Player death function for Player
func _on_death() -> void:
	# We tell our state machine to switch to the DeadState.
	state_machine.change_state("Dead")
	
	# Create an instance of our Game Over screen.
	var game_over_instance = GameOverScreen.instantiate()
	# Add it to the parent (level) scene tree.
	get_tree().current_scene.add_child(game_over_instance)

## Enemy died function for Player
func _on_enemy_died(enemy_stats_data: CharacterStats) -> void:
	# When an enemy dies, add its XP reward to our stats.
	stats_component.add_xp(enemy_stats_data.xp_reward)
