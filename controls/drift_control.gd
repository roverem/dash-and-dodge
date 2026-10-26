extends ShipControl
class_name DriftControl

var grip := 14.0
var drift_grip := 2.2
var drift_steer_boost := 1.35

func physics_tick(state: PhysicsDirectBodyState3D) -> void:
	var axes: Vector2 = read_axis_steer_throttle()
	var drifting := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_select")
	if Input.is_action_pressed("ui_accept"):
		drifting = true

	var planar := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	var speed := planar.length()
	var steer_rate: float = ship.steer_speed_still if speed < 1.0 else ship.steer_speed
	if drifting:
		steer_rate *= drift_steer_boost
	ship.facing -= axes.x * steer_rate * state.step

	var forward: Vector3 = ship.forward_vector()
	if axes.y != 0.0:
		ship.apply_planar_force(state, forward * axes.y * ship.accel)

	var right := Vector3(forward.z, 0.0, -forward.x)
	var lateral := planar.dot(right)
	var grip_strength: float = drift_grip if drifting else grip
	var cancel: Vector3 = -right * lateral * grip_strength
	state.apply_central_force(Vector3(cancel.x, 0.0, cancel.z))

	ship.settle_angular(state)
