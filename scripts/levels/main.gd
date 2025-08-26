# main.gd
extends Node2D

# scene nodes (testing)
@onready var player = $Player 

func _unhandled_input(event: InputEvent) -> void:
	# Temporary test: Press 'Tab' to deal X damage
	if event.is_action_pressed("ui_text_completion_replace"): # Default for Tab key, easy to use
		if is_instance_valid(player): # only apply to player
			var player_stats = player.get_node("StatsComponent")
			if player_stats: # only if statscomponent exists
				player_stats.take_damage(1) # apply dmg
				
	# New temporary test: Press '1' to use X mana
	if Input.is_action_just_pressed("skill_1"): # 1 custome keyb key
		if is_instance_valid(player): # only apply to player
			var player_stats = player.get_node("StatsComponent")
			if player_stats: # only if statscomponent exists
				player_stats.use_mana(10) # use mana
