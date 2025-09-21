# attack_component.gd
# A component that handles the logic of executing an attack.
class_name AttackComponent
extends Node

# A signal to announce when the attack animation/duration is over.
signal attack_finished

# The data defining the attack's properties.
@export var attack_data: AttackData

@onready var animation_component: AnimationComponent = get_owner().get_node("AnimationComponent")
@onready var duration_timer: Timer = Timer.new() # A timer used internally to manage the attack's duration.

func _ready() -> void:
	if not animation_component:
		push_error("AttackComponent requires a sibling AnimationComponent.")
		queue_free() # remove it
		return # early exit
		
	# We create the timer in code and add it as a child.
	# This keeps the component self-contained.
	duration_timer.one_shot = true
	duration_timer.timeout.connect(on_timer_timeout)
	add_child(duration_timer)

# The main public function to start the attack.
func execute(target: Node2D) -> void:
	if not attack_data:
		push_error("AttackComponent has no AttackData.")
		emit_signal("attack_finished") # Fail safely
		return # early exit

	# Get the animation from the AnimationPlayer
	var anim = animation_component.animation_player.get_animation(attack_data.animation_name)
	if not anim:
		push_error("Animation '%s' not found in AttackComponent." % attack_data.animation_name)
		emit_signal("attack_finished")
		return
	
	# We now play the animation and start the timer unconditionally.
	# An attack commits the character to the action, even if the target is gone.
	animation_component.play_animation(attack_data.animation_name)
	# Get the animation's length and start the timer with it.
	var anim_duration = anim.length
	duration_timer.start(anim_duration)
	
	# Only attempt to deal damage if the target is still valid.
	if is_instance_valid(target):
		# Get the character's total damage from the StatCalculator.
		var total_damage = owner.get_total_stat("damage")
		# Find the target's StatsComponent and deal damage.
		var target_stats: StatsComponent = target.get_node("StatsComponent")
		if target_stats:
			# Get the ID of the player we're attacking...
			var target_owner_id = target.get_multiplayer_authority()
			# Add the attacker's ID to the RPC call
			var my_id = multiplayer.get_unique_id()
			# Instead of dealing damage directly, we send a request to the server (peer ID).
			target_stats.server_take_damage.rpc_id(target_owner_id, total_damage, my_id)

func on_timer_timeout() -> void:
	# When the timer finishes, we emit the signal.
	emit_signal("attack_finished")
