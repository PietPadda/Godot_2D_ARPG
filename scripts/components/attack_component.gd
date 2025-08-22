# attack_component.gd
# A component that handles the logic of executing an attack.
class_name AttackComponent
extends Node

# A signal to announce when the attack animation/duration is over.
signal attack_finished

# The data defining the attack's properties.
@export var attack_data: AttackData

# A timer used internally to manage the attack's duration.
@onready var duration_timer: Timer = Timer.new()

func _ready() -> void:
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
		return
		
	if not is_instance_valid(target):
		print("Invalid target.")
		emit_signal("attack_finished") # Fail safely
		return

	print("Attacking %s for %d damage!" % [target.name, attack_data.damage])
	
	 # Find the target's StatsComponent and deal damage.
	var target_stats: StatsComponent = target.get_node("StatsComponent")
	if target_stats:
		target_stats.take_damage(attack_data.damage)
	
	duration_timer.start(attack_data.duration)

func on_timer_timeout() -> void:
	# When the timer finishes, we emit the signal.
	emit_signal("attack_finished")
