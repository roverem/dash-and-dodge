extends ShipControl
class_name MoveAimControl

var _aim_screen := Vector2.ZERO
var _has_aim := false
var _touch_aim_index := -1

func unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_aim_screen = mm.position
		_has_aim = true
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var vp_size: Vector2 = ship.get_viewport().get_visible_rect().size
		if st.pressed and st.position.x >= vp_size.x * 0.5:
			_touch_aim_index = st.index
			_aim_screen = st.position
			_has_aim = true
			ship.get_viewport().set_input_as_handled()
		elif not st.pressed and st.index == _touch_aim_index:
			_touch_aim_index = -1
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		var vp_size2: Vector2 = ship.get_viewport().get_visible_rect().size
		if sd.index == _touch_aim_index or (_touch_aim_index < 0 and sd.position.x >= vp_size2.x * 0.5):
			_aim_screen = sd.position
			_has_aim = true
			_touch_aim_index = sd.index
			ship.get_viewport().set_input_as_handled()

func process(_delta: float) -> void:
	if not _has_aim:
		_aim_screen = ship.get_viewport().get_mouse_position()
		_has_aim = true
	var hit: Variant = ship.ray_ground(_aim_screen)
	if hit == null:
		return
	var to: Vector3 = (hit as Vector3) - ship.global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		ship.facing = atan2(to.x, to.z)

func physics_tick(state: PhysicsDirectBodyState3D) -> void:
	var move: Vector2 = read_move_vector()
	if move != Vector2.ZERO:
		var basis: Basis = camera_basis_xz()
		var world_dir: Vector3 = (basis.x * move.x + (-basis.z) * move.y).normalized()
		ship.apply_planar_force(state, world_dir * ship.accel)
	ship.settle_angular(state)
