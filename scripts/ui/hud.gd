# hud.gd
extends CanvasLayer

# scene nodes
@onready var health_bar: ProgressBar = $PlayerHealthBar

func _ready() -> void:
	# We need a reference to the player to connect to their signals.
	# Using groups is a clean way to find the player.
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_stats = player.get_node("StatsComponent")
		# Connect our UI update function to the player's signal.
		player_stats.health_changed.connect(on_player_health_changed)

func on_player_health_changed(current_health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
