# loot_drop.gd
class_name LootDrop
extends Area2D

# scene nodes
@onready var sprite: Sprite2D = $Sprite2D

# This function will be called by whatever spawns the loot.
func initialize(item_data: ItemData) -> void:
	sprite.texture = item_data.texture
