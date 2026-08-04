extends Sprite2D

@onready var area: Area2D = $Area2D

func _ready() -> void:
	# Connect signals from the Area child node
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	material.set_shader_parameter("is_hovered", true)

func _on_mouse_exited() -> void:
	material.set_shader_parameter("is_hovered", false)
