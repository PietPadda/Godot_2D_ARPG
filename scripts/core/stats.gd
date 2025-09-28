# scripts/core/stats.gd
# A globally accessible container for all stat name constants.
class_name Stats

enum STAT {
	DAMAGE,
	RANGE,
	MOVE_SPEED,
	MAX_HEALTH,
	MAX_MANA,
	STRENGTH,
	# Add any new stats here in the future
}

const STAT_NAMES = [
	"damage",
	"range",
	"move_speed",
	"max_health",
	"max_mana",
	"strength",
]
