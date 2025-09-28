# data/items/stat_modifier.gd
# A resource to hold a single stat and its value.
class_name StatModifier
extends Resource

# This will create a dropdown in the Inspector using our global Stats enum.
@export var stat: Stats.STAT

# The value to modify the stat by.
@export var value: float
