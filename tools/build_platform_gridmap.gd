extends SceneTree

## Headless: builds MeshLibrary and rewrites ship_arena Road as a GridMap.
## Run: godot --headless --path . -s res://tools/build_platform_gridmap.gd

const MESHLIB_PATH := "res://tiles/platform_road_meshlib.tres"
const ARENA_PATH := "res://ship_arena.tscn"
const STRAIGHT_ID := 0
const CORNER_ID := 1
const CELL := 4

func _init() -> void:
	_build_meshlib()
	_convert_arena()
	quit()

func _build_meshlib() -> void:
	var lib := MeshLibrary.new()
	var straight := load("res://assets/space/platform_straight.obj") as Mesh
	var corner := load("res://assets/space/platform_corner.obj") as Mesh
	if straight == null or corner == null:
		push_error("Failed to load platform meshes")
		quit()
		return

	lib.create_item(STRAIGHT_ID)
	lib.set_item_name(STRAIGHT_ID, "straight")
	lib.set_item_mesh(STRAIGHT_ID, straight)

	lib.create_item(CORNER_ID)
	lib.set_item_name(CORNER_ID, "corner")
	lib.set_item_mesh(CORNER_ID, corner)

	var err := ResourceSaver.save(lib, MESHLIB_PATH)
	if err != OK:
		push_error("Failed to save MeshLibrary: %s" % err)
		quit()
		return
	print("Saved ", MESHLIB_PATH)

func _convert_arena() -> void:
	var packed := load(ARENA_PATH) as PackedScene
	if packed == null:
		push_error("Failed to load ship_arena")
		quit()
		return

	var root := packed.instantiate() as Node3D
	var old_road := root.get_node_or_null("Road")
	if old_road != null:
		old_road.free()

	var grid := GridMap.new()
	grid.name = "Road"
	grid.mesh_library = load(MESHLIB_PATH) as MeshLibrary
	grid.cell_size = Vector3(CELL, CELL, CELL)
	grid.cell_center_x = true
	grid.cell_center_y = false
	grid.cell_center_z = true
	# Platforms sit just above the floor.
	grid.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(grid)
	grid.owner = root

	_paint_loop(grid)

	var spawn := root.get_node_or_null("SpawnPoint") as Marker3D
	if spawn != null:
		spawn.position = Vector3(0.0, 0.5, float(CELL * 3))

	_set_owners(root, root)
	var ps := PackedScene.new()
	var pack_err := ps.pack(root)
	if pack_err != OK:
		push_error("pack failed: %s" % pack_err)
		quit()
		return
	var save_err := ResourceSaver.save(ps, ARENA_PATH)
	if save_err != OK:
		push_error("save arena failed: %s" % save_err)
		quit()
		return
	print("Converted Road to GridMap in ", ARENA_PATH)
	root.free()

func _paint_loop(grid: GridMap) -> void:
	var rot_y0 := _ori(0.0)
	var rot_y90 := _ori(90.0)
	var rot_y180 := _ori(180.0)
	var rot_y270 := _ori(270.0)

	# South / North straights (path along X) — cells x=-6..6
	for x in range(-6, 7):
		grid.set_cell_item(Vector3i(x, 0, 3), STRAIGHT_ID, rot_y90)
		grid.set_cell_item(Vector3i(x, 0, -7), STRAIGHT_ID, rot_y90)

	# West / East straights (path along Z) — cells z=-6..2
	for z in range(-6, 3):
		grid.set_cell_item(Vector3i(-7, 0, z), STRAIGHT_ID, rot_y0)
		grid.set_cell_item(Vector3i(7, 0, z), STRAIGHT_ID, rot_y0)

	# Corners
	grid.set_cell_item(Vector3i(-7, 0, 3), CORNER_ID, rot_y90) # SW
	grid.set_cell_item(Vector3i(7, 0, 3), CORNER_ID, rot_y0) # SE
	grid.set_cell_item(Vector3i(-7, 0, -7), CORNER_ID, rot_y180) # NW
	grid.set_cell_item(Vector3i(7, 0, -7), CORNER_ID, rot_y270) # NE

func _ori(yaw_deg: float) -> int:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var gm := GridMap.new()
	var idx := gm.get_orthogonal_index_from_basis(basis)
	gm.free()
	return idx

func _set_owners(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owners(child, owner)
