extends CharacterBody2D

@export var movement_speed: float = 64.0
@onready var _navigation_agent: NavigationAgent2D = %NavigationAgent2D
@onready var area_of_attack:Sprite2D = %AreaOfAttack

func _ready() -> void:
	_navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))

func set_movement_target(movement_target: Vector2):
	_navigation_agent.set_target_position(movement_target)

func _physics_process(delta):
	# Do not query when the map has never synchronized and is empty.
	if NavigationServer2D.map_get_iteration_id(_navigation_agent.get_navigation_map()) == 0:
		return
	if _navigation_agent.is_navigation_finished():
		return

	var next_path_position: Vector2 = _navigation_agent.get_next_path_position()
	var new_velocity: Vector2 = global_position.direction_to(next_path_position) * movement_speed
	if _navigation_agent.avoidance_enabled:
		_navigation_agent.set_velocity(new_velocity)
	else:
		_on_velocity_computed(new_velocity)

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("click"):
		_navigation_agent.target_position = get_global_mouse_position()
		
	if event.is_action_pressed("w"):
		area_of_attack.visible = !area_of_attack.visible
