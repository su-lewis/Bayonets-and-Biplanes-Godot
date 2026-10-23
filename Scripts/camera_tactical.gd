extends Camera2D

@export_category("Panning & Movement")
@export var max_pan_speed: float = 3500.0 
@export var pan_friction: float = 18.0       
@export var edge_margin: float = 200.0 
@export var edge_pan_acceleration: float = 20.0

@export_category("Zooming & 1080p Layout")
@export var zoom_default: float = 0.6        # Zoomed-out view 
@export var zoom_in_level: float = 1.0       # Zoomed-in view 
@export var zoom_speed: float = 0.1          
@export var ui_panel_height: float = 100.0   # 100px UI panel at screen bottom
@export var world_bottom_edge: float = 980.0 # Absolute bottom Y of BottomLane

@export_category("Quick Jumps (Q & E)")
@export var min_x_bound: float = 0.0         # Leftmost map edge
@export var max_x_bound: float = 40000.0     # Rightmost map edge

var current_velocity_x: float = 0.0
var is_initialized: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	zoom = Vector2(zoom_in_level, zoom_in_level)
	_align_camera(zoom.x)
	is_initialized = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var target_zoom_val = zoom.x
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom_val += zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom_val -= zoom_speed
		
		target_zoom_val = clamp(target_zoom_val, zoom_default, zoom_in_level)
		
		if target_zoom_val != zoom.x:
			_zoom_at_cursor(target_zoom_val)

func _zoom_at_cursor(new_zoom_val: float) -> void:
	var viewport_size = get_viewport_rect().size
	var mouse_screen_x = get_viewport().get_mouse_position().x - (viewport_size.x / 2.0)
	var mouse_world_x = global_position.x + (mouse_screen_x / zoom.x)
	
	zoom = Vector2(new_zoom_val, new_zoom_val)
	_align_camera(new_zoom_val)
	
	global_position.x = mouse_world_x - (mouse_screen_x / zoom.x)

func _align_camera(current_zoom: float) -> void:
	var screen_center_to_ui_top = 540.0 - ui_panel_height
	global_position.y = world_bottom_edge - (screen_center_to_ui_top / current_zoom)

func _process(delta: float) -> void:
	if not is_initialized: return

	# --- 1. Q and E QUICK JUMPS (Instant Clean Cut) ---
	if Input.is_key_pressed(KEY_Q):
		global_position.x = min_x_bound
		current_velocity_x = 0.0
		return
	elif Input.is_key_pressed(KEY_E):
		global_position.x = max_x_bound
		current_velocity_x = 0.0
		return

	# --- 2. INSTANT-RESPONSE A / D KEY PANNING ---
	var key_direction = 0.0
	if Input.is_key_pressed(KEY_D):
		key_direction += 1.0
	if Input.is_key_pressed(KEY_A):
		key_direction -= 1.0

	if key_direction != 0.0:
		var target_vel = key_direction * max_pan_speed
		current_velocity_x = lerp(current_velocity_x, target_vel, 25.0 * delta)
	else:
		# --- 3. EDGE PANNING & MOMENTUM SLIDE ---
		var edge_direction = _get_edge_pan_direction()
		if edge_direction != 0.0:
			var target_vel = edge_direction * max_pan_speed
			current_velocity_x = lerp(current_velocity_x, target_vel, edge_pan_acceleration * delta)
		else:
			current_velocity_x = lerp(current_velocity_x, 0.0, pan_friction * delta)

	global_position.x += current_velocity_x * delta

func _get_edge_pan_direction() -> float:
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport_rect().size
	var safe_margin = max(edge_margin, 1.0)
	
	if mouse_pos.x >= screen_size.x - safe_margin:
		var depth = mouse_pos.x - (screen_size.x - safe_margin)
		return clamp(depth / safe_margin, 0.0, 1.0)
	elif mouse_pos.x <= safe_margin:
		var depth = safe_margin - mouse_pos.x
		return -clamp(depth / safe_margin, 0.0, 1.0)
	
	return 0.0
