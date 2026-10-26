extends Area3D
class_name PickupCoin

@export var respawn_delay := 8.0
@export var bob_amplitude := 0.28
@export var bob_speed := 2.2
@export var spin_speed := 2.4

@onready var _visual: Node3D = %Visual
@onready var _mesh: MeshInstance3D = %CoinMesh

var _base_y := 0.0
var _phase := 0.0
var _available := true
var _respawn_left := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # player
	monitoring = true
	monitorable = false
	_base_y = position.y
	_phase = randf() * TAU
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func configure(delay: float, phase_offset: float = -1.0) -> void:
	respawn_delay = delay
	if phase_offset >= 0.0:
		_phase = phase_offset

func _physics_process(delta: float) -> void:
	if not _available:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			_respawn()
		return
	_phase += bob_speed * delta
	if _visual != null:
		_visual.position.y = sin(_phase) * bob_amplitude
		_visual.rotate_y(spin_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if not _available:
		return
	if body.is_in_group("player_ship") or body is BallShip:
		_collect()

func _collect() -> void:
	_available = false
	# Cannot change monitoring inside body_entered — defer it.
	set_deferred("monitoring", false)
	if _mesh != null:
		_mesh.visible = false
	_respawn_left = respawn_delay

func _respawn() -> void:
	_available = true
	set_deferred("monitoring", true)
	if _mesh != null:
		_mesh.visible = true
	_phase = randf() * TAU
