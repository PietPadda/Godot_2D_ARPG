# main.gd
extends Node2D

# A reference to the TargetDummy node in the scene.
@onready var dummy = $TargetDummy

func _unhandled_input(event: InputEvent) -> void:
	# Temporary test: Press 'Tab' to deal 10 damage to the dummy.
	if event.is_action_pressed("ui_text_completion_replace"): # Default for Tab key, easy to use
		if is_instance_valid(dummy): # only apply to dummy
			var dummy_stats = dummy.get_node("StatsComponent")
			if dummy_stats: # only if statscomponent exists
				dummy_stats.take_damage(10) # apply dmg
		
