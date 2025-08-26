# event_bus.gd
## A global singleton for broadcasting game-wide events.
extends Node

# event bus global signals
signal enemy_died(stats_data: CharacterStats)
