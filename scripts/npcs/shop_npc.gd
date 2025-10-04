# scripts/npcs/shop_npc.gd
# Manages the behavior and interactions for the shop NPC.
class_name ShopNPC
extends CharacterBody2D

func _ready() -> void:
	pass

# This function is called by the InteractionArea's signal when a body enters.
func _on_interaction_area_body_entered(body: Node2D) -> void:
	# Announce that the player is in range via the global EventBus.
	if body.is_in_group("player"):
		EventBus.player_entered_shop_range.emit()

# This function is called by the InteractionArea's signal when a body exits.
func _on_interaction_area_body_exited(body: Node2D) -> void:
	# Announce that the player has left range.
	if body.is_in_group("player"):
		EventBus.player_exited_shop_range.emit()
