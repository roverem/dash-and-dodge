extends RigidBody3D
class_name BallShip

@export_group("Driving")
@export var accel := 55.0
@export var max_speed := 28.0
@export var steer_speed := 2.8
@export var steer_speed_still := 4.2
@export var visual_y := 0.15
@export var angular_settle := 0.85
@export var overspeed_force_scale := 0.15

@export_group("Laser Trail")
@export var ring_scene: PackedScene = preload("res://laser_ring.tscn")
@export var ring_spacing := 0.85
@export var ring_min_speed := 2.0
@export var trail_enabled := true

var craft_id: String = "craft_speederA"
var _facing := 0.0
var _trail_distance := 0.0
var _last_trail_pos := Vector3.ZERO

@onready var _visual: Node3D = %Visual
@onready var _mesh: MeshInstance3D = %CraftMesh
@onready var _trail_spawn: Marker3D = %TrailSpawn

func setup(mesh: Mesh, id: String) -> void:
	craft_id = id
	if _mesh == null:
		_mesh = %CraftMesh
		_visual = %Visual
		_trail_spawn = %TrailSpawn
	_mesh.mesh = mesh
	_mesh.name = id
	var aabb := mesh.get_aabb()
	_mesh.position = Vector3(0.0, -aabb.position.y + visual_y, 0.0)
	_last_trail_pos = _trail_origin()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var steer := Input.get_axis("ui_left", "ui_right")
	var throttle := Input.get_axis("ui_down", "ui_up")
	if Input.is_physical_key_pressed(KEY_A):
		steer = -1.0
	if Input.is_physical_key_pressed(KEY_D):
		steer = 1.0
	if Input.is_physical_key_pressed(KEY_W):
		throttle = 1.0
	if Input.is_physical_key_pressed(KEY_S):
		throttle = -1.0

	var planar := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	var speed := planar.length()
	var steer_rate := steer_speed_still if speed < 1.0 else steer_speed
	_facing -= steer * steer_rate * state.step

	var forward := Vector3(sin(_facing), 0.0, cos(_facing))
	if throttle != 0.0:
		var force := forward * throttle * accel
		if speed > max_speed and planar.normalized().dot(force.normalized()) > 0.0:
			force *= overspeed_force_scale
		state.apply_central_force(force)

	var av := state.angular_velocity
	av.x *= angular_settle
	av.z *= angular_settle
	state.angular_velocity = av

func _process(_delta: float) -> void:
	if _visual == null:
		return
	_visual.global_position = global_position
	_visual.rotation = Vector3(0.0, _facing, 0.0)
	_update_trail()

func _trail_origin() -> Vector3:
	if _trail_spawn != null:
		return _trail_spawn.global_position
	return global_position

func _update_trail() -> void:
	if not trail_enabled or ring_scene == null:
		return
	var origin := _trail_origin()
	var planar_vel := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if planar_vel.length() < ring_min_speed:
		_last_trail_pos = origin
		return
	var delta_pos := origin - _last_trail_pos
	delta_pos.y = 0.0
	_trail_distance += delta_pos.length()
	_last_trail_pos = origin
	while _trail_distance >= ring_spacing:
		_trail_distance -= ring_spacing
		_spawn_ring(origin)

func _spawn_ring(origin: Vector3) -> void:
	var ring := ring_scene.instantiate() as Node3D
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(ring)
	ring.global_position = origin
	ring.rotation = Vector3(0.0, _facing, 0.0)
