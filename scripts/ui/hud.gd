# hud.gd
extends CanvasLayer

# scene nodes
@onready var health_bar: ProgressBar = $PlayerHealthBar
@onready var inventory_panel = $InventoryPanel

func _ready() -> void:
	# We need a reference to the player to connect to their signals.
	# Using groups is a clean way to find the player.
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_stats = player.get_node("StatsComponent")
		# Connect our UI update function to the player's signal.
		player_stats.health_changed.connect(on_player_health_changed)
		
		# Connect to the new inventory signal.
		var player_inventory = player.get_node("InventoryComponent")
		player_inventory.inventory_changed.connect(inventory_panel.redraw)
		# Call the new initialize function ONCE.
		inventory_panel.initialize_inventory(player_inventory.inventory_data)

func _unhandled_input(event: InputEvent) -> void:
	# Toggle the inventory panel's visibility.
	if Input.is_action_just_pressed("toggle_inventory"):
		inventory_panel.visible = not inventory_panel.visible

func on_player_health_changed(current_health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
