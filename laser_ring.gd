extends Node3D
class_name LaserRing

@export var lifetime := 1.4
@export var start_scale := 1.0
@export var end_scale := 2.2

@onready var _mesh: MeshInstance3D = %Mesh

var _age := 0.0
var _mat: StandardMaterial3D

func _ready() -> void:
	scale = Vector3.ONE * start_scale
	if _mesh != null and _mesh.material_override is StandardMaterial3D:
		_mat = (_mesh.material_override as StandardMaterial3D).duplicate()
		_mesh.material_override = _mat

func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / lifetime, 0.0, 1.0)
	var s := lerpf(start_scale, end_scale, t)
	scale = Vector3(s, s * 0.25, s)
	if _mat != null:
		var c := _mat.albedo_color
		c.a = lerpf(1.0, 0.0, t * t)
		_mat.albedo_color = c
		_mat.emission_energy_multiplier = lerpf(8.0, 0.0, t)
	if t >= 1.0:
		queue_free()
