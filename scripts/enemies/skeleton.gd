# skeleton.gd
extends CharacterBody2D

# Preload the scenes and resources we need to spawn.
const LootDropScene = preload("res://scenes/items/loot_drop.tscn")
const GoldCoinData = preload("res://data/items/gold_coin.tres")
const CrudeSwordData = preload("res://data/items/crude_sword.tres")

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
	# Announce the death and pass along our stats data.
	EventBus.emit_signal("enemy_died", stats_component.stats_data)
	
	# Create an instance of the loot drop.
	var loot_instance = LootDropScene.instantiate()
	# Position it where the enemy died.
	loot_instance.global_position = global_position
	# Add it to the main scene, not to the enemy.
	get_tree().current_scene.add_child(loot_instance)
	
	# ONLY NOW SAFE TO CALL INIT
	# Initialize it with our crude sword data.
	loot_instance.initialize(CrudeSwordData)
	
	# When this enemy dies, it should remove itself from the game.
	queue_free()
