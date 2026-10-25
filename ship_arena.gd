extends Node3D
class_name ShipArena

const BALL_SHIP_SCENE := preload("res://ball_ship.tscn")
const SELECT_SCENE := preload("res://ship_select.tscn")
const ARENA_SCENE := preload("res://ship_arena.tscn")
## Explicit preloads so Web "export selected scenes" keeps every craft mesh.
const CRAFT_MESHES := {
	"craft_speederA": preload("res://assets/space/craft_speederA.obj"),
	"craft_speederB": preload("res://assets/space/craft_speederB.obj"),
	"craft_speederC": preload("res://assets/space/craft_speederC.obj"),
	"craft_speederD": preload("res://assets/space/craft_speederD.obj"),
	"craft_racer": preload("res://assets/space/craft_racer.obj"),
}
const CAMERA_HEIGHT := 22.0
const CAMERA_FOLLOW_LAG := 8.0

@onready var _camera: Camera3D = %Camera3D
@onready var _spawn: Marker3D = %SpawnPoint
@onready var _hint_label: Label = %HintLabel
@onready var _name_label: Label = %NameLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _cubes_root: Node3D = $Cubes
@onready var _end_screen: Control = %EndScreen
@onready var _end_time_label: Label = %EndTimeLabel
@onready var _end_cubes_label: Label = %EndCubesLabel
@onready var _restart_button: Button = %RestartButton
@onready var _mobile_controls: Control = $UI/MobileControls

var _ship: BallShip
var _elapsed := 0.0
var _run_active := false
var _finished := false
var _cube_total := 0

func _ready() -> void:
	if not UserData.has_selection():
		get_tree().change_scene_to_packed(SELECT_SCENE)
		return
	_cube_total = _count_cubes()
	_end_screen.visible = false
	_restart_button.pressed.connect(_on_restart_pressed)
	UserData.cubes_activated_changed.connect(_on_cubes_activated_changed)
	UserData.reset_run_progress()
	_elapsed = 0.0
	_finished = false
	_run_active = true
	_update_timer_label()
	_spawn_player(UserData.selected_craft_id)

func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_packed(SELECT_SCENE)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _run_active and not _finished:
		_elapsed += delta
		_update_timer_label()
	if _ship == null or not is_instance_valid(_ship) or _finished:
		return
	var target := _ship.global_position + Vector3(0.0, CAMERA_HEIGHT, 8.0)
	_camera.global_position = _camera.global_position.lerp(target, 1.0 - exp(-CAMERA_FOLLOW_LAG * delta))
	_camera.look_at(_ship.global_position, Vector3.UP)

func _count_cubes() -> int:
	var total := 0
	for child in _cubes_root.get_children():
		if child is CountdownCube:
			total += 1
	return total

func _spawn_player(craft_id: String) -> void:
	var mesh: Mesh = CRAFT_MESHES.get(craft_id) as Mesh
	if mesh == null:
		push_error("Unknown craft: %s" % craft_id)
		get_tree().change_scene_to_packed(SELECT_SCENE)
		return

	_ship = BALL_SHIP_SCENE.instantiate() as BallShip
	_ship.name = "PlayerShip"
	add_child(_ship)
	_ship.global_position = _spawn.global_position
	_ship.setup(mesh, craft_id)

	_hint_label.text = "Drive: WASD / arrows / on-screen · stay near cubes to capture\nEsc — back to ship select"
	_refresh_progress_label()
	_camera.make_current()
	_camera.global_position = _ship.global_position + Vector3(0.0, CAMERA_HEIGHT, 8.0)
	_camera.look_at(_ship.global_position, Vector3.UP)

func _refresh_progress_label() -> void:
	_name_label.text = "Driving: %s · Cubes: %d / %d" % [
		UserData.selected_craft_id,
		UserData.cubes_activated,
		_cube_total,
	]

func _update_timer_label() -> void:
	_timer_label.text = "Time: %s" % _format_time(_elapsed)

func _format_time(seconds: float) -> String:
	var total_cs := int(floor(seconds * 100.0))
	var mins := total_cs / 6000
	var secs := (total_cs / 100) % 60
	var cs := total_cs % 100
	return "%d:%02d.%02d" % [mins, secs, cs]

func _on_cubes_activated_changed(count: int) -> void:
	_refresh_progress_label()
	if _finished:
		return
	if _cube_total > 0 and count >= _cube_total:
		_finish_run()

func _finish_run() -> void:
	_finished = true
	_run_active = false
	_update_timer_label()
	if _ship != null and is_instance_valid(_ship):
		_ship.freeze = true
		_ship.set_process(false)
		_ship.set_physics_process(false)
	_end_time_label.text = "Time: %s" % _format_time(_elapsed)
	_end_cubes_label.text = "Cubes captured: %d / %d" % [UserData.cubes_activated, _cube_total]
	if _mobile_controls != null and _mobile_controls.has_method("set_controls_enabled"):
		_mobile_controls.set_controls_enabled(false)
	_end_screen.visible = true

func _on_restart_pressed() -> void:
	UserData.reset_run_progress()
	get_tree().change_scene_to_packed(ARENA_SCENE)
