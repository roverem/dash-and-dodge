extends Node

signal cubes_activated_changed(count: int)

## Global player selection and progress carried between scenes.
var selected_craft_id: String = ""
var cubes_activated: int = 0

func has_selection() -> bool:
	return not selected_craft_id.is_empty()

func clear_selection() -> void:
	selected_craft_id = ""

func reset_run_progress() -> void:
	cubes_activated = 0
	cubes_activated_changed.emit(cubes_activated)

func register_cube_activated() -> void:
	cubes_activated += 1
	cubes_activated_changed.emit(cubes_activated)
