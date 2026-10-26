extends Object
class_name CraftCatalog

enum Scheme {
	ARCADE,
	POINT_CLICK,
	STRAFE,
	MOVE_AIM,
	DRIFT,
}

const ORDER := [
	"craft_speederA",
	"craft_speederB",
	"craft_speederC",
	"craft_speederD",
	"craft_racer",
]

const SCHEME_BY_CRAFT := {
	"craft_speederA": Scheme.ARCADE,
	"craft_speederB": Scheme.POINT_CLICK,
	"craft_speederC": Scheme.STRAFE,
	"craft_speederD": Scheme.MOVE_AIM,
	"craft_racer": Scheme.DRIFT,
}

const DISPLAY_NAME := {
	"craft_speederA": "Arcade",
	"craft_speederB": "Point & Click",
	"craft_speederC": "Strafe",
	"craft_speederD": "Move + Aim",
	"craft_racer": "Drift",
}

const HINT := {
	Scheme.ARCADE: "Steer ←→ · throttle ↑↓ / WASD",
	Scheme.POINT_CLICK: "Right-click (or tap) ground to send ship",
	Scheme.STRAFE: "WASD / pad — camera-locked strafe",
	Scheme.MOVE_AIM: "WASD move · mouse aims nose · thrust along move",
	Scheme.DRIFT: "Arcade + Space / Drift to slide",
}

const MOBILE_PATHS := {
	Scheme.ARCADE: "res://controls/mobile_arcade.tscn",
	Scheme.POINT_CLICK: "res://controls/mobile_point_click.tscn",
	Scheme.STRAFE: "res://controls/mobile_strafe.tscn",
	Scheme.MOVE_AIM: "res://controls/mobile_move_aim.tscn",
	Scheme.DRIFT: "res://controls/mobile_drift.tscn",
}

## ---------------------------------------------------------------------------
## EDIT MOVEMENT HERE — one block per craft (independent).
## Shared keys (all schemes): accel, max_speed, steer_speed, steer_speed_still,
##   overspeed_force_scale, linear_damp, angular_damp, mass
## Point & click only: arrive_radius, arrive_slow_radius
## Drift only: grip, drift_grip, drift_steer_boost
## ---------------------------------------------------------------------------
const PROFILES := {
	"craft_speederA": {
		"accel": 55.0,
		"max_speed": 28.0,
		"steer_speed": 2.8,
		"steer_speed_still": 4.2,
		"overspeed_force_scale": 0.15,
		"linear_damp": 1.2,
		"angular_damp": 4.0,
		"mass": 1.2,
	},
	"craft_speederB": {
		"accel": 90.0,
		"max_speed": 24.0,
		"steer_speed": 10.2,
		"steer_speed_still": 40.6,
		"overspeed_force_scale": 0.15,
		"linear_damp": 1.4,
		"angular_damp": 4.0,
		"mass": 1.2,
		"arrive_radius": 1.25,
		"arrive_slow_radius": 4.0,
	},
	"craft_speederC": {
		"accel": 60.0,
		"max_speed": 26.0,
		"steer_speed": 2.8,
		"steer_speed_still": 4.2,
		"overspeed_force_scale": 0.12,
		"linear_damp": 1.6,
		"angular_damp": 4.0,
		"mass": 1.1,
	},
	"craft_speederD": {
		"accel": 52.0,
		"max_speed": 27.0,
		"steer_speed": 0.8,
		"steer_speed_still": 0.2,
		"overspeed_force_scale": 0.15,
		"linear_damp": 1.3,
		"angular_damp": 4.0,
		"mass": 1.2,
	},
	"craft_racer": {
		"accel": 62.0,
		"max_speed": 32.0,
		"steer_speed": 4,
		"steer_speed_still": 3.8,
		"overspeed_force_scale": 0.2,
		"linear_damp": 1.0,
		"angular_damp": 3.5,
		"mass": 1.0,
		"grip": 14.0,
		"drift_grip": 2.2,
		"drift_steer_boost": 1.35,
	},
}

static func scheme_for(craft_id: String) -> Scheme:
	return SCHEME_BY_CRAFT.get(craft_id, Scheme.ARCADE) as Scheme

static func profile_for(craft_id: String) -> Dictionary:
	if PROFILES.has(craft_id):
		return PROFILES[craft_id]
	return PROFILES["craft_speederA"]

static func apply_to_ship(ship, craft_id: String) -> void:
	var p: Dictionary = profile_for(craft_id)
	if p.has("accel"):
		ship.accel = float(p["accel"])
	if p.has("max_speed"):
		ship.max_speed = float(p["max_speed"])
	if p.has("steer_speed"):
		ship.steer_speed = float(p["steer_speed"])
	if p.has("steer_speed_still"):
		ship.steer_speed_still = float(p["steer_speed_still"])
	if p.has("overspeed_force_scale"):
		ship.overspeed_force_scale = float(p["overspeed_force_scale"])
	if p.has("linear_damp"):
		ship.linear_damp = float(p["linear_damp"])
	if p.has("angular_damp"):
		ship.angular_damp = float(p["angular_damp"])
	if p.has("mass"):
		ship.mass = float(p["mass"])

static func make_control(craft_id: String) -> ShipControl:
	var p: Dictionary = profile_for(craft_id)
	match scheme_for(craft_id):
		Scheme.POINT_CLICK:
			var pc := PointClickControl.new()
			if p.has("arrive_radius"):
				pc.arrive_radius = float(p["arrive_radius"])
			if p.has("arrive_slow_radius"):
				pc.arrive_slow_radius = float(p["arrive_slow_radius"])
			return pc
		Scheme.STRAFE:
			return StrafeControl.new()
		Scheme.MOVE_AIM:
			return MoveAimControl.new()
		Scheme.DRIFT:
			var drift := DriftControl.new()
			if p.has("grip"):
				drift.grip = float(p["grip"])
			if p.has("drift_grip"):
				drift.drift_grip = float(p["drift_grip"])
			if p.has("drift_steer_boost"):
				drift.drift_steer_boost = float(p["drift_steer_boost"])
			return drift
		_:
			return ArcadeControl.new()

static func mobile_scene_for(craft_id: String) -> PackedScene:
	var path: String = MOBILE_PATHS.get(scheme_for(craft_id), MOBILE_PATHS[Scheme.ARCADE])
	return load(path) as PackedScene

static func hint_for(craft_id: String) -> String:
	return HINT.get(scheme_for(craft_id), HINT[Scheme.ARCADE]) as String

static func display_name_for(craft_id: String) -> String:
	return DISPLAY_NAME.get(craft_id, craft_id) as String
