extends Area3D
class_name CountdownCube

enum EscapePhase { NONE, WAITING, TELEGRAPH, THRUST }

const PLAYER_GROUP := "player_ship"
const ARENA_LIMIT := 70.0

@export var countdown_seconds := 10.0
## Seconds per countdown unit while recovering after the player leaves (0.5 = 2× countdown speed).
@export var recover_seconds_per_unit := 0.5
@export var idle_material: Material
@export var active_material: Material
@export var link_max_distance := 7.0
@export var link_thickness := 0.45

@export_group("Escape")
## Seconds after capture starts before the first telegraph + jump.
@export var first_escape_delay := 1.35
## Seconds to wait after a jump before starting the next telegraph (while still captured).
@export var escape_interval := 2.1
## How long the cube faces away, crouches, and wiggles before thrusting.
@export var telegraph_time := 0.85
## Duration of the burst leap itself (seconds).
@export var thrust_time := 0.3
## How far the cube leaps away from the player. Should exceed link_max_distance to break the link.
@export var jump_distance := 9.5
## Max yaw/tilt wiggle angle during the telegraph, in degrees.
@export var wiggle_degrees := 22.0
## Wiggle oscillation speed in cycles per second during the telegraph.
@export var wiggle_hz := 9.0
## How far the mesh dips downward while preparing to jump (world units).
@export var crouch_amount := 0.18
## Show a yellow arrow for the hop direction (live aim during telegraph).
@export var show_debug_arrow := true

@export_group("Attractor")
## Gently pull the cube toward the player when nearby (tractor-beam feel).
@export var attractor_enabled := true
## Planar distance at which the beam starts pulling.
@export var attractor_range := 10.0
## Max pull speed (units/sec) at point-blank. Keep low so escape hops still work.
@export var attractor_speed := 1.6
## If true, pull fades from full strength at 0 distance to 0 at attractor_range.
@export var attractor_falloff := true

@export_group("Body")
## Min planar distance (ship center ↔ cube center) so the solid cube stays outside the hull.
@export var body_clearance := 1.55

@onready var _mesh: MeshInstance3D = %CubeMesh
@onready var _label: Label3D = %CountdownLabel
@onready var _laser: MeshInstance3D = %LaserLink
@onready var _debug_arrow: Node3D = %DebugArrow
@onready var _solid: AnimatableBody3D = $SolidBody

var _player_inside := false
var _recovering := false
var _remaining := 0.0
var _done := false
var _ship: BallShip
var _laser_mat: ShaderMaterial

var _escape_phase: EscapePhase = EscapePhase.NONE
var _escape_timer := 0.0
var _escape_dir := Vector3(0.0, 0.0, 1.0)
var _thrust_from := Vector3.ZERO
var _thrust_to := Vector3.ZERO
var _mesh_rest_pos := Vector3.ZERO
var _face_yaw := 0.0

func _ready() -> void:
	# Capture Area is detection-only; SolidBody child handles ship blocking.
	collision_layer = 0
	collision_mask = 2 # player layer
	monitoring = true
	monitorable = false
	_remaining = countdown_seconds
	_mesh_rest_pos = _mesh.position
	_apply_idle_visual()
	_setup_laser()
	_sync_solid_body()

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
	_update_escape(delta)
	_update_attractor(delta)
	_update_capture_state()
	if _player_inside:
		_recovering = false
		_remaining = maxf(0.0, _remaining - delta)
		_refresh_countdown_label()
		if _remaining <= 0.0:
			_complete()
	elif _recovering:
		var recover_rate := 1.0 / maxf(recover_seconds_per_unit, 0.001)
		_remaining = minf(countdown_seconds, _remaining + delta * recover_rate)
		_refresh_countdown_label()
		if _remaining >= countdown_seconds:
			_remaining = countdown_seconds
			_recovering = false
			_label.visible = false

func _process(_delta: float) -> void:
	if _done or not _player_inside:
		return
	_update_laser_link()

func _refresh_countdown_label() -> void:
	_label.visible = true
	_label.text = str(clampi(ceili(_remaining), 0, ceili(countdown_seconds)))

func _update_capture_state() -> void:
	# Poll every physics frame. Relying only on body_entered/exited breaks after
	# we move the Area3D (stale overlaps → cube can never be re-captured).
	var ship := _find_ship_in_range()
	if ship != null:
		if not _player_inside:
			_begin_capture(ship)
		else:
			_ship = ship
	elif _player_inside:
		_break_link(false)

func _find_ship_in_range() -> BallShip:
	if monitoring:
		for body in get_overlapping_bodies():
			if body is BallShip and _planar_distance_to(body as Node3D) <= link_max_distance:
				return body as BallShip
	# Distance fallback — overlap cache often goes stale after we move the Area3D.
	for node in get_tree().get_nodes_in_group(PLAYER_GROUP):
		if node is BallShip and _planar_distance_to(node as Node3D) <= link_max_distance:
			return node as BallShip
	return null

func _planar_distance_to(node: Node3D) -> float:
	var delta := node.global_position - global_position
	delta.y = 0.0
	return delta.length()

func _update_attractor(delta: float) -> void:
	if not attractor_enabled or attractor_speed <= 0.0 or attractor_range <= 0.0:
		return
	# Don't fight the escape hop — pull only when the cube isn't thrusting away.
	if _escape_phase == EscapePhase.THRUST:
		return
	var ship := _find_ship_within(attractor_range)
	if ship == null:
		return
	var to_ship := ship.global_position - global_position
	to_ship.y = 0.0
	var dist := to_ship.length()
	var clearance := maxf(body_clearance, 0.05)
	if dist <= clearance:
		_separate_from_ship(ship)
		return
	var strength := 1.0
	if attractor_falloff:
		strength = 1.0 - clampf(dist / attractor_range, 0.0, 1.0)
	if strength <= 0.0:
		return
	var step_len := attractor_speed * strength * delta
	step_len = minf(step_len, dist - clearance)
	var next := global_position + to_ship / dist * step_len
	next.y = global_position.y
	_set_cube_position(_clamp_to_arena(next))

func _find_ship_within(max_distance: float) -> BallShip:
	for node in get_tree().get_nodes_in_group(PLAYER_GROUP):
		if node is BallShip and _planar_distance_to(node as Node3D) <= max_distance:
			return node as BallShip
	return null

func _separate_from_ship(ship: BallShip = null) -> void:
	if ship == null:
		ship = _find_ship_within(body_clearance)
	if ship == null or not is_instance_valid(ship):
		return
	var away := global_position - ship.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(1.0, 0.0, 0.0)
	var clearance := maxf(body_clearance, 0.05)
	var next := ship.global_position + away.normalized() * clearance
	next.y = global_position.y
	_set_cube_position(_clamp_to_arena(next))

func _begin_capture(ship: BallShip) -> void:
	var fresh := not _player_inside
	_ship = ship
	_player_inside = true
	_recovering = false
	_refresh_countdown_label()
	if _laser != null:
		_laser.visible = true
	if not fresh:
		return
	# Keep current _remaining (partial progress / mid-recover). Start escape cycle on new capture.
	if _escape_phase != EscapePhase.THRUST:
		_start_waiting(first_escape_delay)

func _break_link(force_cancel_thrust: bool) -> void:
	if not _player_inside and _ship == null:
		if force_cancel_thrust:
			_cancel_escape()
		return
	_player_inside = false
	_ship = null
	_hide_laser()
	# Count back up from the interrupted value instead of snapping to full.
	if _remaining < countdown_seconds:
		_recovering = true
		_refresh_countdown_label()
	else:
		_recovering = false
		_label.visible = false
	if force_cancel_thrust or _escape_phase != EscapePhase.THRUST:
		_cancel_escape()

func _start_waiting(delay: float) -> void:
	_escape_phase = EscapePhase.WAITING
	_escape_timer = delay
	_restore_mesh_pose()
	_update_debug_arrow(false)

func _cancel_escape() -> void:
	_escape_phase = EscapePhase.NONE
	_escape_timer = 0.0
	_restore_mesh_pose()
	_update_debug_arrow(false)

func _update_debug_arrow(active: bool) -> void:
	if _debug_arrow == null:
		return
	if not show_debug_arrow or not active:
		_debug_arrow.visible = false
		return
	_debug_arrow.visible = true
	# Arrow mesh is +Y; aim that axis along escape direction.
	var up := Vector3.UP
	if absf(_escape_dir.dot(up)) > 0.95:
		up = Vector3.RIGHT
	var axis_y := _escape_dir
	var axis_x := up.cross(axis_y).normalized()
	var axis_z := axis_x.cross(axis_y)
	_debug_arrow.global_transform = Transform3D(Basis(axis_x, axis_y, axis_z), _mesh.global_position)

func _aim_away_from_ship() -> bool:
	if _ship == null or not is_instance_valid(_ship):
		return false
	var away := global_position - _ship.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	_escape_dir = away.normalized()
	_face_yaw = atan2(_escape_dir.x, _escape_dir.z)
	return true

func _begin_telegraph() -> void:
	# Wind-up faces away from the player now; the real hop re-aims at thrust time.
	if not _aim_away_from_ship():
		_cancel_escape()
		return
	_escape_phase = EscapePhase.TELEGRAPH
	_escape_timer = telegraph_time
	_apply_face_pose(0.0, 0.0)

func _begin_thrust() -> void:
	# Jump direction is decided here — away from the player at launch.
	if not _aim_away_from_ship():
		_cancel_escape()
		return
	_thrust_from = global_position
	_thrust_to = _clamp_to_arena(_thrust_from + _escape_dir * jump_distance)
	# Only side-dodge when the arena wall clipped most of this hop — not whenever
	# jump_distance itself is shorter than the capture radius.
	var hop_length := _thrust_from.distance_to(_thrust_to)
	if hop_length < jump_distance * 0.5:
		var side := Vector3(-_escape_dir.z, 0.0, _escape_dir.x)
		if randf() < 0.5:
			side = -side
		var side_target := _clamp_to_arena(_thrust_from + side.normalized() * jump_distance)
		if _thrust_from.distance_to(side_target) > hop_length:
			_escape_dir = side.normalized()
			_face_yaw = atan2(_escape_dir.x, _escape_dir.z)
			_thrust_to = side_target
	_thrust_to.y = _thrust_from.y
	_escape_phase = EscapePhase.THRUST
	_escape_timer = thrust_time
	_restore_mesh_pose()
	_apply_face_pose(0.0, 0.0)

func _clamp_to_arena(pos: Vector3) -> Vector3:
	pos.x = clampf(pos.x, -ARENA_LIMIT, ARENA_LIMIT)
	pos.z = clampf(pos.z, -ARENA_LIMIT, ARENA_LIMIT)
	return pos

func _set_cube_position(pos: Vector3) -> void:
	global_position = pos
	_sync_solid_body()

func _sync_solid_body() -> void:
	if _solid == null:
		return
	# SolidBody is top_level so parent Area moves don't drag physics automatically.
	_solid.global_transform = Transform3D(Basis.IDENTITY, global_position)

func _refresh_monitoring() -> void:
	if _done:
		return
	monitoring = false
	call_deferred("_reenable_monitoring")

func _reenable_monitoring() -> void:
	if _done:
		return
	monitoring = true

func _update_escape(delta: float) -> void:
	match _escape_phase:
		EscapePhase.NONE:
			return
		EscapePhase.WAITING:
			if not _player_inside:
				return
			_escape_timer -= delta
			if _escape_timer <= 0.0:
				_begin_telegraph()
		EscapePhase.TELEGRAPH:
			if not _player_inside:
				_cancel_escape()
				return
			_escape_timer -= delta
			var t := 1.0 - clampf(_escape_timer / maxf(telegraph_time, 0.001), 0.0, 1.0)
			var wobble := sin(Time.get_ticks_msec() * 0.001 * TAU * wiggle_hz)
			var crouch := -crouch_amount * sin(t * PI)
			# Preview live escape aim (matches re-aim at thrust).
			_aim_away_from_ship()
			_apply_face_pose(wobble * deg_to_rad(wiggle_degrees), crouch)
			_mesh.position = _mesh_rest_pos + Vector3(
				_escape_dir.z * wobble * 0.1,
				crouch,
				-_escape_dir.x * wobble * 0.1
			)
			_update_debug_arrow(true)
			if _escape_timer <= 0.0:
				_begin_thrust()
		EscapePhase.THRUST:
			_escape_timer -= delta
			var u := 1.0 - clampf(_escape_timer / maxf(thrust_time, 0.001), 0.0, 1.0)
			var eased := 1.0 - pow(1.0 - u, 3.0)
			_set_cube_position(_thrust_from.lerp(_thrust_to, eased))
			_apply_face_pose(0.0, 0.0)
			_update_debug_arrow(true)
			if _escape_timer <= 0.0:
				_set_cube_position(_thrust_to)
				_separate_from_ship()
				_restore_mesh_pose()
				_update_debug_arrow(false)
				_refresh_monitoring()
				# Keep hopping while the player is still capturing; stop when they break off.
				var ship := _find_ship_in_range()
				if ship != null:
					_ship = ship
					_player_inside = true
					_start_waiting(escape_interval)
				else:
					_escape_phase = EscapePhase.NONE
					if _player_inside:
						_break_link(true)

func _apply_face_pose(yaw_wiggle: float, _crouch: float) -> void:
	_mesh.rotation = Vector3(0.0, _face_yaw + yaw_wiggle, yaw_wiggle * 0.35)

func _restore_mesh_pose() -> void:
	_mesh.position = _mesh_rest_pos
	_mesh.rotation = Vector3(0.0, _face_yaw, 0.0)

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

	_laser.visible = true
	_laser.scale = Vector3.ONE
	_laser.global_position = mid
	_laser.look_at(to, up)
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
	_cancel_escape()
	_face_yaw = 0.0
	_restore_mesh_pose()
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
	_restore_mesh_pose()
