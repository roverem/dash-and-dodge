extends Node2D

signal on_hit

@export var speed = 150.0

func _ready() -> void:
	on_hit.connect(when_hit)

func _physics_process(delta: float) -> void:
	position.x += speed * delta
	if position.x > 1200:
		position.x = 0

func when_hit(direction) -> void:
	position += direction
