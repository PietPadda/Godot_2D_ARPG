# health_bar.gd
extends ProgressBar

func _ready() -> void:
	# Hide the health bar by default. Show it when damage is first taken.
	visible = false

func update_health(current_health: int, max_health: int) -> void:
	max_value = max_health # set max
	value = current_health # updat current
	if current_health < max_health:
		visible = true # reveal when NOT full
