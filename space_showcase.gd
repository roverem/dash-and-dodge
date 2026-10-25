extends Node3D
class_name SpaceShowcase

const FOLDER := "res://assets/space"
const SPACING := 4.0
const ORBIT_SENS := 0.005
const PAN_SENS := 0.0015
const ZOOM_MIN := 2.0
const ZOOM_MAX := 200.0
const MOVE_SPEED := 60.0

var _camera: Camera3D
var _env: Environment
var _light: DirectionalLight3D
var _target := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.55
var _distance := 40.0
var _orbiting := false
var _panning := false

var _assets: Array[MeshInstance3D] = []
var _selected: MeshInstance3D
var _selection_overlay: StandardMaterial3D
var _name_label: Label
var _path_label: Label
var _liked_list: ItemList
var _liked: PackedStringArray = []

func _ready() -> void:
	_selection_overlay = StandardMaterial3D.new()
	_selection_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_overlay.albedo_color = Color(0.15, 0.75, 1.0, 0.35)
	_selection_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var files := _list_obj_files()
	var cols := maxi(ceili(sqrt(files.size())), 1)
	var count := 0
	for file_name in files:
		var mesh := load(FOLDER.path_join(file_name)) as Mesh
		if mesh == null:
			continue
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.name = file_name.get_basename()
		instance.set_meta("asset_file", file_name)
		instance.set_meta("asset_path", FOLDER.path_join(file_name))
		instance.position = Vector3(
			float(count % cols) * SPACING,
			0.0,
			floorf(float(count) / float(cols)) * SPACING
		)
		add_child(instance)
		_assets.append(instance)
		count += 1

	var rows := maxi(ceili(float(count) / float(cols)), 1)
	var span := maxf(cols, rows) * SPACING
	_target = Vector3(
		float(cols - 1) * SPACING * 0.5,
		0.0,
		float(rows - 1) * SPACING * 0.5
	)
	_distance = span * 0.72
	_setup_floor(span)
	_setup_environment()
	_setup_light()
	_setup_camera()
	_setup_lighting_panel()
	_setup_selection_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_select_at(event.position)
			MOUSE_BUTTON_RIGHT:
				_orbiting = event.pressed
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_distance = maxf(_distance * 0.9, ZOOM_MIN)
					_apply_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_distance = minf(_distance * 1.1, ZOOM_MAX)
					_apply_camera()
	elif event is InputEventMouseMotion:
		if _orbiting:
			_yaw -= event.relative.x * ORBIT_SENS
			_pitch = clampf(_pitch + event.relative.y * ORBIT_SENS, 0.05, 1.45)
			_apply_camera()
		elif _panning:
			var right := _camera.global_basis.x
			var up := _camera.global_basis.y
			_target += (-right * event.relative.x + up * event.relative.y) * _distance * PAN_SENS
			_apply_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			_like_selected()

func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		move.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		move.y -= 1.0
	if move == Vector3.ZERO:
		return
	var yaw_basis := Basis(Vector3.UP, _yaw)
	_target += yaw_basis * move.normalized() * MOVE_SPEED * delta * (_distance / 40.0)
	_apply_camera()

func _list_obj_files() -> PackedStringArray:
	var files: PackedStringArray = []
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		return files
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".obj"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files

func _setup_floor(span: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.roughness = 0.85
	var plane := PlaneMesh.new()
	plane.size = Vector2(span + SPACING * 4.0, span + SPACING * 4.0)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.material_override = material
	floor_mesh.position = _target + Vector3(0.0, -0.01, 0.0)
	add_child(floor_mesh)

func _setup_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.08, 0.09, 0.12)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.45, 0.48, 0.55)
	_env.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = _env
	add_child(world)

func _setup_light() -> void:
	_light = DirectionalLight3D.new()
	_light.name = "Sun"
	_light.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	_light.light_energy = 1.2
	_light.shadow_enabled = true
	add_child(_light)

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.current = true
	add_child(_camera)
	_apply_camera()

func _apply_camera() -> void:
	var offset := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	) * _distance
	_camera.global_position = _target + offset
	_camera.look_at(_target)

func _select_at(screen_pos: Vector2) -> void:
	var hit := _pick_asset(screen_pos)
	_set_selected(hit)

func _pick_asset(screen_pos: Vector2) -> MeshInstance3D:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var best: MeshInstance3D = null
	var best_dist := INF
	for asset in _assets:
		var inv := asset.global_transform.affine_inverse()
		var local_origin := inv * origin
		var local_dir := inv.basis * dir
		var hit = asset.get_aabb().intersects_ray(local_origin, local_dir)
		if hit == null:
			continue
		var world_hit: Vector3 = asset.global_transform * (hit as Vector3)
		var dist := origin.distance_squared_to(world_hit)
		if dist < best_dist:
			best_dist = dist
			best = asset
	return best

func _set_selected(asset: MeshInstance3D) -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.material_overlay = null
	_selected = asset
	if _selected == null:
		_name_label.text = "Selected: (none)"
		_path_label.text = ""
		return
	_selected.material_overlay = _selection_overlay
	var file_name := str(_selected.get_meta("asset_file", _selected.name))
	var path := str(_selected.get_meta("asset_path", ""))
	_name_label.text = "Selected: %s" % _selected.name
	_path_label.text = path
	print("[showcase] selected: %s (%s)" % [_selected.name, file_name])

func _like_selected() -> void:
	if _selected == null:
		return
	var file_name := str(_selected.get_meta("asset_file", _selected.name))
	if file_name in _liked:
		return
	_liked.append(file_name)
	_liked_list.add_item(file_name)
	print("[showcase] liked: %s" % file_name)

func _setup_selection_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SelectionUI"
	layer.layer = 10
	add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "SelectionPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.position = Vector2(-296, 16)
	panel.custom_minimum_size = Vector2(280, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Asset Picker"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	var hint := Label.new()
	hint.text = "Left-click mesh · L to like"
	hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	root.add_child(hint)

	_name_label = Label.new()
	_name_label.text = "Selected: (none)"
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_name_label)

	_path_label = Label.new()
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	root.add_child(_path_label)

	var like_btn := Button.new()
	like_btn.text = "Like selected (L)"
	like_btn.pressed.connect(_like_selected)
	root.add_child(like_btn)

	var liked_title := Label.new()
	liked_title.text = "Liked"
	liked_title.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	root.add_child(liked_title)

	_liked_list = ItemList.new()
	_liked_list.custom_minimum_size = Vector2(0, 160)
	_liked_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_liked_list)

func _setup_lighting_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LightingUI"
	layer.layer = 10
	add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "LightingPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(280, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Global Lighting"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	root.add_child(_make_section("Sun"))
	_add_color_row(root, "Color", _light.light_color, func(c: Color) -> void:
		_light.light_color = c
	)
	_add_slider_row(root, "Energy", 0.0, 8.0, 0.05, _light.light_energy, func(v: float) -> void:
		_light.light_energy = v
	)
	_add_slider_row(root, "Pitch", -89.0, 89.0, 1.0, _light.rotation_degrees.x, func(v: float) -> void:
		_light.rotation_degrees.x = v
	)
	_add_slider_row(root, "Yaw", -180.0, 180.0, 1.0, _light.rotation_degrees.y, func(v: float) -> void:
		_light.rotation_degrees.y = v
	)
	var shadows := CheckButton.new()
	shadows.text = "Shadows"
	shadows.button_pressed = _light.shadow_enabled
	shadows.toggled.connect(func(on: bool) -> void:
		_light.shadow_enabled = on
	)
	root.add_child(shadows)

	root.add_child(_make_section("Ambient"))
	_add_color_row(root, "Color", _env.ambient_light_color, func(c: Color) -> void:
		_env.ambient_light_color = c
	)
	_add_slider_row(root, "Energy", 0.0, 4.0, 0.05, _env.ambient_light_energy, func(v: float) -> void:
		_env.ambient_light_energy = v
	)

	root.add_child(_make_section("Background"))
	_add_color_row(root, "Color", _env.background_color, func(c: Color) -> void:
		_env.background_color = c
	)

func _make_section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	return label

func _add_slider_row(
	parent: Control,
	label_text: String,
	min_value: float,
	max_value: float,
	step: float,
	initial: float,
	on_change: Callable
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 56
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 120
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 40
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%.2f" % initial
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%.2f" % v
		on_change.call(v)
	)

func _add_color_row(parent: Control, label_text: String, initial: Color, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 56
	row.add_child(label)

	var picker := ColorPickerButton.new()
	picker.color = initial
	picker.custom_minimum_size = Vector2(120, 24)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.color_changed.connect(on_change)
	row.add_child(picker)
