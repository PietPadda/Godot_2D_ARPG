# character_stats.gd
# A data container for a character's base stats. It holds data and has no logic.
class_name CharacterStats
extends Resource

# Description
## A data container for a character's base stats. It holds data and has no logic.

@export var level: int = 1
@export var current_xp: int = 0
@export var xp_to_next_level: int = 100
@export var xp_reward: int = 0

@export var max_health: int = 100
@export var max_mana: int = 50
@export var strength: int = 10
@export var move_speed: float = 200.0
