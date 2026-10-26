extends RefCounted
class_name ShipControl

## Host ship (BallShip). Kept untyped to avoid class_name parse cycles.
var ship

func setup(host) -> void:
	ship = host

func teardown() -> void:
	ship = null

func unhandled_input(_event: InputEvent) -> void:
	pass

func physics_tick(_state: PhysicsDirectBodyState3D) -> void:
	pass

func process(_delta: float) -> void:
	pass

func read_axis_steer_throttle() -> Vector2:
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
	return Vector2(steer, throttle)

func read_move_vector() -> Vector2:
	var x := Input.get_axis("ui_left", "ui_right")
	var y := Input.get_axis("ui_down", "ui_up")
	if Input.is_physical_key_pressed(KEY_A):
		x = -1.0
	if Input.is_physical_key_pressed(KEY_D):
		x = 1.0
	if Input.is_physical_key_pressed(KEY_W):
		y = 1.0
	if Input.is_physical_key_pressed(KEY_S):
		y = -1.0
	if x != 0.0 or y != 0.0:
		return Vector2(x, y).limit_length(1.0)
	return Vector2.ZERO

func camera_basis_xz() -> Basis:
	var cam: Camera3D = ship.get_follow_camera()
	if cam == null:
		return Basis.IDENTITY
	var forward := -cam.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, 1.0)
	else:
		forward = forward.normalized()
	var right := cam.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		right = Vector3(1.0, 0.0, 0.0)
	else:
		right = right.normalized()
	return Basis(right, Vector3.UP, -forward)
