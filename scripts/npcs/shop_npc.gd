# scripts/npcs/shop_npc.gd
# Manages the behavior and interactions for the shop NPC.
class_name ShopNPC
extends CharacterBody2D

# This variable will hold the state of whether the player can interact.
var _is_player_in_range: bool = false

func _ready() -> void:
	# We'll add initialization logic here later.
	pass

# This function is called by the InteractionArea's signal when a body enters.
func _on_interaction_area_body_entered(body: Node2D) -> void:
	# We check if the body is the player by checking its group.
	if body.is_in_group("player"):
		_is_player_in_range = true
		print("Player is now in range of the NPC.")

# This function is called by the InteractionArea's signal when a body exits.
func _on_interaction_area_body_exited(body: Node2D) -> void:
	# We check if the exiting body was the player.
	if body.is_in_group("player"):
		_is_player_in_range = false
		print("Player has left the NPC's range.")
