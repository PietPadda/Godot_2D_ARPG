# scripts/core/anims.gd
# A globally accessible container for all animation name constants.
class_name Anims

# --- Skeleton Animations ---
enum SKELETON {
	IDLE,
	MOVE,
	ATTACK,
	DEAD
}
const SKELETON_NAMES = [
	"Idle",
	"Move",
	"Attack",
	"Dead"
]

# --- Player Animations ---
enum PLAYER {
	IDLE,
	MOVE,
	ATTACK,
	DEAD
}
const PLAYER_NAMES = [
	"Idle",
	"Move",
	"Attack",
	"Dead"
]
