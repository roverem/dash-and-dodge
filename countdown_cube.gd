extends Area3D
class_name CountdownCube

@export var countdown_seconds := 10.0
@export var idle_material: Material
@export var active_material: Material
@export var link_max_distance := 7.0
@export var link_thickness := 0.45

@onready var _mesh: MeshInstance3D = %CubeMesh
@onready var _label: Label3D = %CountdownLabel
@onready var _laser: MeshInstance3D = %LaserLink

var _player_inside := false
var _remaining := 0.0
var _done := false
var _ship: BallShip
var _laser_mat: ShaderMaterial

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_remaining = countdown_seconds
	_apply_idle_visual()
	_setup_laser()

func _setup_laser() -> void:
	if _laser == null:
		return
	_laser.visible = false
	_laser.top_level = true
	_laser.extra_cull_margin = 8.0
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _laser.material_override is ShaderMaterial:
		_laser_mat = (_laser.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		_laser.material_override = _laser_mat

func _physics_process(delta: float) -> void:
	if _done:
		return
	if not _player_inside:
		return
	_remaining = maxf(0.0, _remaining - delta)
	_label.text = str(ceili(_remaining))
	if _remaining <= 0.0:
		_complete()

func _process(_delta: float) -> void:
	if _done or not _player_inside:
		return
	_update_laser_link()

func _on_body_entered(body: Node3D) -> void:
	if _done or not body is BallShip:
		return
	_ship = body as BallShip
	_player_inside = true
	_remaining = countdown_seconds
	_label.visible = true
	_label.text = str(ceili(_remaining))
	if _laser != null:
		_laser.visible = true

func _on_body_exited(body: Node3D) -> void:
	if _done or body != _ship:
		return
	_player_inside = false
	_ship = null
	_remaining = countdown_seconds
	_label.text = str(ceili(_remaining))
	_label.visible = false
	_hide_laser()

func _update_laser_link() -> void:
	if _laser == null or _laser_mat == null:
		return
	if _ship == null or not is_instance_valid(_ship):
		_hide_laser()
		return

	var from := _ship.global_position + Vector3(0.0, 0.5, 0.0)
	var to := _mesh.global_position
	var offset := to - from
	var distance := offset.length()
	if distance < 0.08:
		_laser.visible = false
		return

	var mid := from + offset * 0.5
	var up := Vector3.UP
	var forward := offset / distance
	if absf(forward.dot(up)) > 0.95:
		up = Vector3.RIGHT

	# Orthonormal pose + uniform-ish scale (avoids broken AABB / culling).
	_laser.visible = true
	_laser.scale = Vector3.ONE
	_laser.global_position = mid
	_laser.look_at(to, up)
	# Cylinder is Y-up; look_at aims -Z, so tip +Y toward the cube.
	_laser.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	_laser.scale = Vector3(link_thickness, distance, link_thickness)

	var strength := clampf(1.0 - (distance / maxf(link_max_distance, 0.01)), 0.2, 1.0)
	_laser_mat.set_shader_parameter("link_strength", strength)

func _hide_laser() -> void:
	if _laser != null:
		_laser.visible = false
	if _laser_mat != null:
		_laser_mat.set_shader_parameter("link_strength", 0.0)

func _complete() -> void:
	_done = true
	_player_inside = false
	_ship = null
	monitoring = false
	_label.text = "0"
	_label.visible = true
	_hide_laser()
	if active_material != null:
		_mesh.material_override = active_material
	UserData.register_cube_activated()

func _apply_idle_visual() -> void:
	if idle_material != null:
		_mesh.material_override = idle_material
	_label.visible = false
	_label.text = str(ceili(countdown_seconds))
