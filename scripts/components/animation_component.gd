# animation_component.gd
# A component to simplify playing animations on its parent.
class_name AnimationComponent
extends Node

@onready var animation_player: AnimationPlayer = get_parent().get_node("AnimationPlayer")

# A public function to play a named animation.
func play_animation(anim_name: String) -> void:
	# Check if the animation exists to prevent errors.
	if not animation_player.has_animation(anim_name):
		push_warning("Animation '%s' not found." % anim_name)
		return

	# Play the new animation.
	animation_player.play(anim_name)
