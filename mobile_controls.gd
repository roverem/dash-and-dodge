extends Control
## On-screen touch overlay. Holds feed the same ui_* actions as keyboard.

@export var show_on_touchscreen := true
@export var show_on_mobile := true
@export var show_on_web := true
@export var force_visible := false

@onready var _btn_left: BaseButton = %BtnLeft
@onready var _btn_right: BaseButton = %BtnRight
@onready var _btn_accel: BaseButton = %BtnAccel
@onready var _btn_back: BaseButton = %BtnBack

const _ACTIONS := {
	"left": "ui_left",
	"right": "ui_right",
	"accel": "ui_up",
	"back": "ui_down",
}

var _held: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_visibility()
	_wire(_btn_left, "left")
	_wire(_btn_right, "right")
	_wire(_btn_accel, "accel")
	_wire(_btn_back, "back")
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

func _wire(btn: BaseButton, key: String) -> void:
	if btn == null:
		return
	btn.focus_mode = Control.FOCUS_NONE
	btn.button_down.connect(_on_down.bind(key))
	btn.button_up.connect(_on_up.bind(key))

func _on_down(key: String) -> void:
	var action: String = _ACTIONS[key]
	_held[key] = true
	Input.action_press(action)

func _on_up(key: String) -> void:
	var action: String = _ACTIONS[key]
	_held.erase(key)
	if Input.is_action_pressed(action):
		Input.action_release(action)

func _release_all() -> void:
	for key in _ACTIONS.keys():
		var action: String = _ACTIONS[key]
		if _held.has(key) or Input.is_action_pressed(action):
			Input.action_release(action)
	_held.clear()
