# scripts/core/state_manager.gd
class_name StateManager
extends Node

# Enum for the player's possible states, using integers.
enum PLAYER {
	IDLE,   # = 0
	MOVE,   # = 1
	CHASE,  # = 2
	ATTACK, # = 3
	CAST,   # = 4
	DEAD    # = 5
}
# An array to map the PLAYER enum to the node names in the scene tree.
const PLAYER_STATE_NAMES = [
	"Idle", "Move", "Chase", "Attack", "Cast", "Dead"
]

# Enum for the enemy's possible states.
enum ENEMY {
	IDLE,   # = 0
	CHASE,  # = 1
	ATTACK  # = 2
}

# An array to map the ENEMY enum to the node names in the scene tree.
const ENEMY_STATE_NAMES = [
	"Idle", "Chase", "Attack"
]

# An enum for skill slots. This lets us use readable names instead of numbers.
enum SkillSlots {
	SECONDARY, # This will have a value of 0
	SKILL_1,   # 1
	SKILL_2,   # 2
	SKILL_3,   # 3
	SKILL_4    # 4
}
