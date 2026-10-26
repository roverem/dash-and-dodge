extends ShipControl
class_name StrafeControl

func physics_tick(state: PhysicsDirectBodyState3D) -> void:
	var move: Vector2 = read_move_vector()
	var basis: Basis = camera_basis_xz()
	var cam_forward: Vector3 = -basis.z
	ship.facing = atan2(cam_forward.x, cam_forward.z)
	if move != Vector2.ZERO:
		var world_dir: Vector3 = (basis.x * move.x + (-basis.z) * move.y).normalized()
		ship.apply_planar_force(state, world_dir * ship.accel)
	ship.settle_angular(state)
