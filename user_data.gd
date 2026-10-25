extends Node

## Global player selection carried between scenes.
var selected_craft_id: String = ""

func has_selection() -> bool:
	return not selected_craft_id.is_empty()

func clear_selection() -> void:
	selected_craft_id = ""
