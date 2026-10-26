extends Control
## Touch pad that presses InputMap actions while buttons are held.

@export var show_on_touchscreen := true
@export var show_on_mobile := true
@export var show_on_web := true
@export var force_visible := false

## button unique name -> input action
@export var button_actions: Dictionary = {
	"BtnLeft": "ui_left",
	"BtnRight": "ui_right",
	"BtnAccel": "ui_up",
	"BtnBack": "ui_down",
	"BtnDrift": "ui_accept",
}

var _held: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_visibility()
	for btn_name in button_actions.keys():
		var node := find_child(str(btn_name), true, false)
		if node is BaseButton:
			_wire(node as BaseButton, str(button_actions[btn_name]), str(btn_name))
	if not get_viewport().size_changed.is_connected(_update_visibility):
		get_viewport().size_changed.connect(_update_visibility)

func _exit_tree() -> void:
	_release_all()

func set_controls_enabled(enabled: bool) -> void:
	if not enabled:
		_release_all()
	visible = enabled and _should_show()

func _should_show() -> bool:
	if force_visible:
		return true
	if show_on_touchscreen and DisplayServer.is_touchscreen_available():
		return true
	if show_on_mobile and (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		return true
	if show_on_web and OS.has_feature("web"):
		return true
	return false

func _update_visibility() -> void:
	visible = _should_show()

func _wire(btn: BaseButton, action: String, key: String) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.button_down.connect(_on_down.bind(action, key))
	btn.button_up.connect(_on_up.bind(action, key))

func _on_down(action: String, key: String) -> void:
	_held[key] = action
	Input.action_press(action)

func _on_up(action: String, key: String) -> void:
	_held.erase(key)
	if Input.is_action_pressed(action):
		Input.action_release(action)

func _release_all() -> void:
	for key in _held.keys():
		var action: String = _held[key]
		if Input.is_action_pressed(action):
			Input.action_release(action)
	_held.clear()
