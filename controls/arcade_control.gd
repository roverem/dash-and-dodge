extends ShipControl
class_name ArcadeControl

func physics_tick(state: PhysicsDirectBodyState3D) -> void:
	var axes: Vector2 = read_axis_steer_throttle()
	var planar := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	var speed := planar.length()
	var steer_rate: float = ship.steer_speed_still if speed < 1.0 else ship.steer_speed
	ship.facing -= axes.x * steer_rate * state.step
	var forward: Vector3 = ship.forward_vector()
	if axes.y != 0.0:
		ship.apply_planar_force(state, forward * axes.y * ship.accel)
	ship.settle_angular(state)
