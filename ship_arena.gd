extends Node3D
class_name ShipArena

const BALL_SHIP_SCENE := preload("res://ball_ship.tscn")
const SELECT_SCENE := "res://ship_select.tscn"
const CAMERA_HEIGHT := 22.0
const CAMERA_FOLLOW_LAG := 8.0

@onready var _camera: Camera3D = %Camera3D
@onready var _spawn: Marker3D = %SpawnPoint
@onready var _hint_label: Label = %HintLabel
@onready var _name_label: Label = %NameLabel

var _ship: BallShip

func _ready() -> void:
	if not UserData.has_selection():
		get_tree().change_scene_to_file(SELECT_SCENE)
		return
	_spawn_player(UserData.selected_craft_id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(SELECT_SCENE)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _ship == null or not is_instance_valid(_ship):
		return
	var target := _ship.global_position + Vector3(0.0, CAMERA_HEIGHT, 8.0)
	_camera.global_position = _camera.global_position.lerp(target, 1.0 - exp(-CAMERA_FOLLOW_LAG * delta))
	_camera.look_at(_ship.global_position, Vector3.UP)

func _spawn_player(craft_id: String) -> void:
	var mesh := load("res://assets/space/%s.obj" % craft_id) as Mesh
	if mesh == null:
		push_error("Unknown craft: %s" % craft_id)
		get_tree().change_scene_to_file(SELECT_SCENE)
		return

	_ship = BALL_SHIP_SCENE.instantiate() as BallShip
	_ship.name = "PlayerShip"
	add_child(_ship)
	_ship.global_position = _spawn.global_position
	_ship.setup(mesh, craft_id)

	_hint_label.text = "Drive: WASD / arrows\nEsc — back to ship select"
	_name_label.text = "Driving: %s" % craft_id
	_camera.make_current()
	_camera.global_position = _ship.global_position + Vector3(0.0, CAMERA_HEIGHT, 8.0)
	_camera.look_at(_ship.global_position, Vector3.UP)
