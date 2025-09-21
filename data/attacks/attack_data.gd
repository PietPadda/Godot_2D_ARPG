# attack_data.gd
# A data container for an attack's properties.
class_name AttackData
extends Resource

# Description
## A data container for an attack's properties.

@export var damage: float = 10.0
@export var range: float = 75.0 # all attacks have range, even melee!
@export var animation_name: String = "Attack" # Default ot Attack
