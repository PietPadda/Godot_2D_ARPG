# scripts/core/item_database.gd
extends Node

# This dictionary will hold all of our pre-loaded items, keyed by their resource path.
var items_by_path := {}

func _ready() -> void:
	# This function runs once when the game starts.
	_scan_for_items("res://data/items")
	print("[ItemDatabase] Loaded %s items." % items_by_path.size())

# Recursively scans directories to find and load all ItemData resources.
func _scan_for_items(path: String) -> void:
	var dir = DirAccess.open(path) # filesystem access
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				_scan_for_items(path.path_join(file_name))
			elif file_name.ends_with(".tres"): # resource file
				var item_path = path.path_join(file_name)
				var item_resource = load(item_path)
				# We only add valid ItemData resources to our database.
				if item_resource is ItemData:
					items_by_path[item_path] = item_resource
			file_name = dir.get_next() # next element in dir
	else:
		push_error("ItemDatabase: Could not open directory at path: %s" % path)

# The global function to get an item from the database.
func get_item(path: String) -> ItemData:
	return items_by_path.get(path, null)
