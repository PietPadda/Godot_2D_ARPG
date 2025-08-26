# skill_data.gd
class_name SkillData
extends Resource

# Description
## A data container for all skill properties.

# exported vars
@export var skill_name: String = "New Skill"
@export var mana_cost: int = 10
@export var damage: int = 50
@export var cast_time: float = 0.5 # time to cast a skill

# exported scenes & data
@export var projectile_scene: PackedScene
@export var projectile_data: ProjectileData
