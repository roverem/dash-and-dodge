extends Node3D
class_name EdgePickups
## Spawns vertical columns of pickup coins along all arena edges.

@export var coin_scene: PackedScene = preload("res://pickup_coin.tscn")
## Distance from arena center to the coin line (walls sit at ~80).
@export var edge_distance := 74.0
@export var spacing := 8.0
@export var coins_per_column := 3
@export var column_height_step := 0.9
@export var base_height := 0.75
@export var respawn_delay := 8.0
## Skip placing a double column exactly on corners (shared by two edges).
@export var skip_corner_duplicates := true

func _ready() -> void:
	if coin_scene == null:
		coin_scene = load("res://pickup_coin.tscn") as PackedScene
	if coin_scene == null:
		push_error("EdgePickups: coin_scene is null")
		return
	_clear_existing()
	_place_edge(true, false)  # north  (-Z)
	_place_edge(true, true)   # south  (+Z)
	_place_edge(false, false) # west   (-X)
	_place_edge(false, true)  # east   (+X)

func _clear_existing() -> void:
	for child in get_children():
		child.queue_free()

func _place_edge(along_x: bool, positive: bool) -> void:
	var half := edge_distance
	var start := -half
	var end := half
	var count := int(floor((end - start) / spacing)) + 1
	for i in count:
		var t := start + float(i) * spacing
		if skip_corner_duplicates and not along_x and (is_equal_approx(t, -half) or is_equal_approx(t, half)):
			continue
		var pos := Vector3.ZERO
		if along_x:
			pos.x = t
			pos.z = half if positive else -half
		else:
			pos.x = half if positive else -half
			pos.z = t
		_spawn_column(pos)

func _spawn_column(base: Vector3) -> void:
	for level in coins_per_column:
		var coin := coin_scene.instantiate() as Area3D
		if coin == null:
			continue
		add_child(coin)
		coin.position = Vector3(base.x, base_height + float(level) * column_height_step, base.z)
		if coin.has_method("configure"):
			coin.configure(respawn_delay, float(level) * 0.7 + randf() * 0.4)
