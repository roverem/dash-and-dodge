extends Node3D
class_name ShipSelect

const ARENA_SCENE := preload("res://ship_arena.tscn")

@export var selection_overlay: Material

@onready var _camera: Camera3D = %Camera3D
@onready var _roster_root: Node3D = %Roster
@onready var _hint_label: Label = %HintLabel
@onready var _name_label: Label = %NameLabel

var _roster: Array[MeshInstance3D] = []
var _selected: MeshInstance3D

func _ready() -> void:
	for child in _roster_root.get_children():
		if child is MeshInstance3D:
			_roster.append(child)
	_hint_label.text = "Left-click a ship to race"
	_name_label.text = "Selected: (none)"
	_camera.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_selected(_pick_roster(event.position))
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit := _pick_roster(event.position)
		if hit != null:
			_confirm(str(hit.get_meta("craft_id")))

func _confirm(craft_id: String) -> void:
	UserData.selected_craft_id = craft_id
	get_tree().change_scene_to_packed(ARENA_SCENE)

func _pick_roster(screen_pos: Vector2) -> MeshInstance3D:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var best: MeshInstance3D = null
	var best_dist := INF
	for ship in _roster:
		var inv := ship.global_transform.affine_inverse()
		var local_origin := inv * origin
		var local_dir := inv.basis * dir
		var hit = ship.get_aabb().intersects_ray(local_origin, local_dir)
		if hit == null:
			continue
		var world_hit: Vector3 = ship.global_transform * (hit as Vector3)
		var dist := origin.distance_squared_to(world_hit)
		if dist < best_dist:
			best_dist = dist
			best = ship
	return best

func _set_selected(ship: MeshInstance3D) -> void:
	if _selected == ship:
		return
	if _selected != null and is_instance_valid(_selected):
		_selected.material_overlay = null
	_selected = ship
	if _selected != null:
		_selected.material_overlay = selection_overlay
		_name_label.text = "Selected: %s" % _selected.get_meta("craft_id")
	else:
		_name_label.text = "Selected: (none)"
