extends ShipControl
class_name PointClickControl

var arrive_radius := 1.25
var arrive_slow_radius := 4.0

var _has_target := false
var _target := Vector3.ZERO

func unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_try_set_target(mb.position)
			ship.get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_try_set_target(st.position)
			ship.get_viewport().set_input_as_handled()

func _try_set_target(screen_pos: Vector2) -> void:
	var hit: Variant = ship.ray_ground(screen_pos)
	if hit == null:
		return
	_target = hit as Vector3
	_target.y = ship.global_position.y
	_has_target = true

func physics_tick(state: PhysicsDirectBodyState3D) -> void:
	if not _has_target:
		ship.settle_angular(state)
		return
	var to: Vector3 = _target - (ship.global_position as Vector3)
	to.y = 0.0
	var dist: float = to.length()
	if dist <= arrive_radius:
		_has_target = false
		ship.settle_angular(state)
		return
	var desired_yaw := atan2(to.x, to.z)
	var yaw_err := wrapf(desired_yaw - ship.facing, -PI, PI)
	var planar := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	var speed := planar.length()
	var steer_rate: float = ship.steer_speed_still if speed < 1.0 else ship.steer_speed
	var max_turn := steer_rate * state.step
	ship.facing += clampf(yaw_err, -max_turn, max_turn)
	var throttle := 1.0
	if dist < arrive_slow_radius:
		throttle = clampf(dist / arrive_slow_radius, 0.25, 1.0)
	if absf(yaw_err) < 0.9:
		var forward: Vector3 = ship.forward_vector()
		ship.apply_planar_force(state, forward * throttle * ship.accel)
	ship.settle_angular(state)
