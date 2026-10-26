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
var facing := 0.0
var follow_camera: Camera3D

var _control
var _trail_distance := 0.0
var _last_trail_pos := Vector3.ZERO

@onready var _visual: Node3D = %Visual
@onready var _mesh: MeshInstance3D = %CraftMesh
@onready var _trail_spawn: Marker3D = %TrailSpawn

func _ready() -> void:
	add_to_group("player_ship")
	if _control == null:
		_set_control(CraftCatalog.make_control(craft_id))

func setup(mesh: Mesh, id: String) -> void:
	craft_id = id
	add_to_group("player_ship")
	if _mesh == null:
		_mesh = %CraftMesh
		_visual = %Visual
		_trail_spawn = %TrailSpawn
	_mesh.mesh = mesh
	_mesh.name = id
	var aabb := mesh.get_aabb()
	_mesh.position = Vector3(0.0, -aabb.position.y + visual_y, 0.0)
	_last_trail_pos = _trail_origin()
	CraftCatalog.apply_to_ship(self, craft_id)
	_set_control(CraftCatalog.make_control(craft_id))

func set_follow_camera(camera: Camera3D) -> void:
	follow_camera = camera

func get_follow_camera() -> Camera3D:
	if follow_camera != null and is_instance_valid(follow_camera):
		return follow_camera
	return get_viewport().get_camera_3d()

func forward_vector() -> Vector3:
	return Vector3(sin(facing), 0.0, cos(facing))

func apply_planar_force(state: PhysicsDirectBodyState3D, force: Vector3) -> void:
	force.y = 0.0
	if force.length_squared() < 0.0001:
		return
	var planar := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	var speed := planar.length()
	if speed > max_speed and planar.normalized().dot(force.normalized()) > 0.0:
		force *= overspeed_force_scale
	state.apply_central_force(force)

func settle_angular(state: PhysicsDirectBodyState3D) -> void:
	var av := state.angular_velocity
	av.x *= angular_settle
	av.z *= angular_settle
	state.angular_velocity = av

func ray_ground(screen_pos: Vector2) -> Variant:
	var cam := get_follow_camera()
	if cam == null:
		return null
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	# Intersect y = ship height plane (arena floor ~0, ship rides slightly above).
	var plane_y := global_position.y
	var t := (plane_y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t

func _set_control(control) -> void:
	if _control != null:
		_control.teardown()
	_control = control
	if _control != null:
		_control.setup(self)

func _unhandled_input(event: InputEvent) -> void:
	if _control != null:
		_control.unhandled_input(event)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _control != null:
		_control.physics_tick(state)
	else:
		settle_angular(state)

func _process(delta: float) -> void:
	if _control != null:
		_control.process(delta)
	if _visual == null:
		return
	_visual.global_position = global_position
	_visual.rotation = Vector3(0.0, facing, 0.0)
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
	ring.rotation = Vector3(0.0, facing, 0.0)
