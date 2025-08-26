# player_targeting_component.gd
class_name PlayerTargetingComponent
extends Node

# This exposes a clickable list of physics layers in the Inspector!
@export_flags_2d_physics var target_layer_mask: int

@onready var player: CharacterBody2D = get_owner()

# This is our centralized, reusable targeting function.
func get_target_under_mouse() -> Node2D:
	var world_space = player.get_world_2d().direct_space_state
	var mouse_pos = player.get_global_mouse_position()
	
	# Set up the query.
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	
	# No more magic numbers! We use the exported mask.
	query.collision_mask = target_layer_mask
	
	# Perform the query.
	var results = world_space.intersect_point(query)
	
	# Return the first valid collider found.
	if not results.is_empty():
		return results[0].collider
	
	return null
