# animation_component.gd
# A component to simplify playing animations on its parent.
class_name AnimationComponent
extends Node

# The AnimationPlayer this component will control is now an injected dependency.
@export var animation_player: AnimationPlayer

# A public function to play a named animation.
func play_animation(anim_name: String) -> void:
	# Add a guard clause to ensure the dependency is met.
	if not animation_player:
		push_warning("AnimationComponent has no AnimationPlayer assigned.")
		return
	
	# Check if the animation exists to prevent errors.
	if not animation_player.has_animation(anim_name):
		push_warning("Animation '%s' not found." % anim_name)
		return

	# Play the new animation.
	animation_player.play(anim_name)
