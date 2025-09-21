# scripts/levels/town.gd
extends BaseLevel

# The setup logic MUST be in _ready() to run once at the start.
func _ready():
	super() # This runs all the logic from BaseLevel._ready()
	# Town-specific logic can go here in the future (e.g., spawning NPCs).
	pass
	
# This function can now be left empty or used for other inputs.
func _unhandled_input(_event: InputEvent) -> void:
	pass
