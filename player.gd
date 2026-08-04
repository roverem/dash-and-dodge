extends CharacterBody2D


var speed = 100.0
var stopping_distance = 10.0

@onready var _navigation_agent: NavigationAgent2D = %NavigationAgent2D
@onready var _timer: Timer = %Timer

var target:Vector2

func _ready() -> void:
	set_physics_process(false)
	_navigation_agent.velocity_computed.connect(translate)
	_navigation_agent.max_speed = speed

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("click"):
		_navigation_agent.target_position = get_global_mouse_position()
		set_physics_process(true)

func _physics_process(delta: float) -> void:
	var next_location := _navigation_agent.get_next_path_position()
	var direction = (next_location - global_position).normalized()
	_navigation_agent.velocity = direction * speed * delta
	var final_location := _navigation_agent.get_final_position()
	print(global_position.distance_to(final_location))
	if global_position.distance_to(final_location) < stopping_distance:
		set_physics_process(false)
		#destination_reached.emit()
	_orient_character_to_direction(delta, direction)
	

func _orient_character_to_direction(delta: float, direction: Vector2) -> void:
	# We use `lerp_angle()` to interpolate between the model's current rotation and
	# the newly calculated rotation, as otherwise the model may turn abruptly.
	rotation = lerp_angle(rotation, direction.angle() + PI / 2.0, 4.0 * delta)
