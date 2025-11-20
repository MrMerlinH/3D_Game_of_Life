extends Camera3D

@export var target: Vector3 = Vector3.ZERO
@export var distance: float = 5.0
@export var rotation_speed: float = 0.01
@export var zoom_speed: float = 1.0
@export var min_distance: float = 2.0
@export var max_distance: float = 20.0

var rotation_x: float = 0.0
var rotation_y: float = 0.0
var rotating: bool = false
var last_mouse_pos: Vector2

func _ready():
	# Initialize position based on starting rotation
	_update_camera_position()

func _unhandled_input(event):
	# Rotate around target with right mouse button
	if event is InputEventMouseButton:
		if event.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
			rotating = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP:
			distance = max(min_distance, distance - zoom_speed)
			_update_camera_position()
		elif event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
			distance = min(max_distance, distance + zoom_speed)
			_update_camera_position()

	elif event is InputEventMouseMotion and rotating:
		var delta = event.relative
		rotation_x -= delta.y * rotation_speed
		rotation_y -= delta.x * rotation_speed
		rotation_x = clamp(rotation_x, deg_to_rad(-89), deg_to_rad(89))
		_update_camera_position()

func _update_camera_position():
	var rot = Basis()
	rot = Basis(Vector3.UP, rotation_y) * Basis(Vector3.RIGHT, rotation_x)
	var offset = rot.z * distance
	global_position = target + offset
	look_at(target)
