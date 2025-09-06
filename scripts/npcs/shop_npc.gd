# scripts/npcs/shop_npc.gd
# Manages the behavior and interactions for the shop NPC.
class_name ShopNPC
extends CharacterBody2D

# Preload the Shop Panel scene so we can create instances of it.
const ShopPanelScene = preload("res://scenes/ui/shop_panel.tscn")

# This variable will hold the state of whether the player can interact.
var _is_player_in_range: bool = false

func _ready() -> void:
	# We'll add initialization logic here later.
	pass
	
# This function listens for any input that wasn't handled by the UI.
func _unhandled_input(event: InputEvent) -> void:
	# We only care about input if the player is in range and presses the interact button.
	if _is_player_in_range and event.is_action_pressed("interact"):
		# Mark the input as "handled" to prevent other nodes from using it.
		get_tree().get_root().set_input_as_handled()
		_open_shop_panel() # open the panel

# This function is called by the InteractionArea's signal when a body enters.
func _on_interaction_area_body_entered(body: Node2D) -> void:
	# We check if the body is the player by checking its group.
	if body.is_in_group("player"):
		_is_player_in_range = true

# This function is called by the InteractionArea's signal when a body exits.
func _on_interaction_area_body_exited(body: Node2D) -> void:
	# We check if the exiting body was the player.
	if body.is_in_group("player"):
		_is_player_in_range = false

# This function handles creating and showing the shop UI.
func _open_shop_panel() -> void:
	# The NPC's only job is to create the panel. The panel handles the rest.
	var shop_panel_instance = ShopPanelScene.instantiate()
	get_tree().get_root().add_child(shop_panel_instance)
