---
name: godot-prefer-editor-scenes
description: >
  Prefer constructing Godot scenes with editor nodes over runtime code
  instancing. Use whenever creating or editing Godot scenes, .tscn/.tres
  files, MeshInstance3D, lights, cameras, UI, collision, or when tempted
  to Node.new()/add_child() static structure in _ready().
---

# Prefer editor-built Godot scenes

Construct scenes with editor nodes whenever possible. Use as few code instancing as possible.

## Workflow

1. Create or open a `.tscn` and add nodes in the editor (or via MCP scene tools).
2. Assign meshes, materials, shapes, and transforms as scene properties.
3. Attach scripts that only drive behavior and reference `$Node` / `%UniqueName`.
4. For reusable actors, make a packed scene and `instantiate()` it — do not rebuild its internals in code.

## Anti-patterns

```gdscript
# BAD — static structure created in code
func _ready() -> void:
	var light := DirectionalLight3D.new()
	add_child(light)
	var mesh := MeshInstance3D.new()
	mesh.mesh = PlaneMesh.new()
	add_child(mesh)
```

```gdscript
# GOOD — nodes exist in the .tscn; script only uses them
@onready var light: DirectionalLight3D = $Sun
@onready var floor_mesh: MeshInstance3D = $ArenaFloor/MeshInstance3D
```

## When code instancing is OK

- Spawning a pre-authored packed scene (`preload("res://ball_ship.tscn").instantiate()`)
- Content that is inherently dynamic and unknown at edit time
---
