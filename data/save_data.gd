# save_data.gd
class_name SaveData
extends Resource

# Description
## A data container for all save game properties.

# Always Persisting Stats
@export var player_stats_data: CharacterStats
@export var player_inventory_data: InventoryData
@export var player_equipment_data: EquipmentData

# Live Stats for Scene Transitions
var current_health: int
var current_mana: int
# Add a variable to hold the target position in the new scene.
var target_spawn_position: Vector2 = Vector2.INF
