# skill_data.gd
class_name SkillData
extends Resource

# Description
## A data container for all skill properties.

@export var skill_name: String = "New Skill"
@export var mana_cost: int = 10
@export var damage: int = 50
@export var speed: float = 400.0 # projectile speed
@export var timer_expire: float = 3.0 # before skill deletes itself

# This will hold the scene for the projectile our skill fires.
@export var projectile_scene: PackedScene
