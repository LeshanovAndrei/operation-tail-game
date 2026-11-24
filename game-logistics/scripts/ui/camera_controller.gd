class_name CameraController
extends Camera2D

const PAN_SPEED: float = 640.0
const MAX_ZOOM: float = 1.85
const ZOOM_STEP: float = 0.12
const ZOOM_SMOOTH: float = 12.0
const DEFAULT_POS: Vector2 = Vector2(940.0, 625.0)
const DEFAULT_ZOOM: float = 0.78
const DRAG_THRESHOLD_PX: float = 6.0

var pan_speed_scale: float = 1.0
var _map_bounds: Rect2 = Rect2(0.0, 0.0, 2200.0, 1250.0)
var _target_zoom: float = DEFAULT_ZOOM
var _press_active: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	position = DEFAULT_POS
	_target_zoom = clampf(DEFAULT_ZOOM, _get_min_zoom(), MAX_ZOOM)
	zoom = Vector2(_target_zoom, _target_zoom)
	_clamp_position()


func set_map_bounds(bounds: Rect2) -> void:
	_map_bounds = bounds
	_target_zoom = clampf(_target_zoom, _get_min_zoom(), MAX_ZOOM)
	zoom = Vector2(_target_zoom, _target_zoom)
	_clamp_position()


func focus_on(world_pos: Vector2) -> void:
	position = world_pos
	_clamp_position()


func zoom_in() -> void:
	_set_target_zoom(_target_zoom + ZOOM_STEP)


func zoom_out() -> void:
	_set_target_zoom(_target_zoom - ZOOM_STEP)


func reset_view() -> void:
	position = _map_bounds.get_center()
	_set_target_zoom(DEFAULT_ZOOM)
	zoom = Vector2(_target_zoom, _target_zoom)
	_clamp_position()


func _process(delta: float) -> void:
	if not is_equal_approx(zoom.x, _target_zoom):
		var next_z: float = lerpf(zoom.x, _target_zoom, minf(1.0, delta * ZOOM_SMOOTH))
		if absf(next_z - _target_zoom) < 0.002:
			next_z = _target_zoom
		zoom = Vector2(next_z, next_z)
		_clamp_position()

	var move_dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_dir.y += 1.0

	if move_dir.length_squared() > 0.0:
		position += move_dir.normalized() * (PAN_SPEED * pan_speed_scale / zoom.x) * delta
		_clamp_position()


func _unhandled_input(event: InputEvent) -> void:
	if _is_pointer_over_ui():
		_press_active = false
		_dragging = false
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_press_active = true
				_dragging = false
				_press_pos = mb.position
			else:
				_press_active = false
				_dragging = false
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
	elif event is InputEventMouseMotion and _press_active:
		var mm: InputEventMouseMotion = event
		if not _dragging and mm.position.distance_to(_press_pos) >= DRAG_THRESHOLD_PX:
			_dragging = true
		if _dragging:
			position -= mm.relative / zoom
			_clamp_position()
	elif event is InputEventKey:
		var kev: InputEventKey = event
		if kev.pressed and not kev.echo and kev.keycode == KEY_R:
			reset_view()


func _set_target_zoom(z: float) -> void:
	_target_zoom = clampf(z, _get_min_zoom(), MAX_ZOOM)


func _get_min_zoom() -> float:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return 0.60
	var zx: float = vp_size.x / maxf(100.0, _map_bounds.size.x)
	var zy: float = vp_size.y / maxf(100.0, _map_bounds.size.y)
	return clampf(maxf(zx, zy) + 0.002, 0.40, MAX_ZOOM)


func _clamp_position() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var half_view: Vector2 = (vp_size * 0.5) / maxf(0.1, zoom.x)
	var min_x: float = _map_bounds.position.x + half_view.x
	var max_x: float = _map_bounds.end.x - half_view.x
	var min_y: float = _map_bounds.position.y + half_view.y
	var max_y: float = _map_bounds.end.y - half_view.y

	if min_x > max_x:
		position.x = _map_bounds.get_center().x
	else:
		position.x = clampf(position.x, min_x, max_x)

	if min_y > max_y:
		position.y = _map_bounds.get_center().y
	else:
		position.y = clampf(position.y, min_y, max_y)


func _is_pointer_over_ui() -> bool:
	var vp: Viewport = get_viewport()
	if vp == null:
		return false
	return vp.gui_get_hovered_control() != null
