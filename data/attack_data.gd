# attack_data.gd
# A data container for an attack's properties.
class_name AttackData
extends Resource

@export var damage: int = 10
@export var duration: float = 0.5 # How long the attack state lasts.
@export var range: float = 75.0 # all attacks have range, even melee!
