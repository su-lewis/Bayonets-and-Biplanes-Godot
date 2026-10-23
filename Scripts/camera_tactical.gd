extends Camera2D

@export_category("Panning")
@export var max_pan_speed: float = 2500.0 
@export var edge_margin: float = 200.0 
@export var edge_pan_acceleration: float = 15.0

@export_category("Zooming & 1080p Layout")
@export var zoom_default: float = 0.6        # Zoomed-out view 
@export var zoom_in_level: float = 1.0       # Zoomed-in view 
@export var zoom_speed: float = 0.1          
@export var ui_panel_height: float = 100.0   # Exactly 100px for your UI panel at the bottom
@export var world_bottom_edge: float = 980.0 # The absolute Y coordinate of your lowest lane's bottom in the world

@export_category("Quick Jumps (Q & E)")
@export var min_x_bound: float = 0.0         
@export var max_x_bound: float = 40000.0     

var current_velocity: float = 0.0
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
	# For a 1080p screen, the center is at Y = 540. 
	# The top of a 100px UI panel sitting at the bottom of a 1080p window is at screen Y = 980.
	# Distance from screen center (540) to UI top (980) is 440 pixels.
	var screen_center_to_ui_top = 540.0 - ui_panel_height
	
	# This locks the bottom edge of your world precisely against the UI at any zoom level, with zero drift.
	global_position.y = world_bottom_edge - (screen_center_to_ui_top / current_zoom)

func _process(delta: float) -> void:
	if not is_initialized: return

	var key_direction = 0.0
	if Input.is_key_pressed(KEY_D):
		key_direction += 1.0
	if Input.is_key_pressed(KEY_A):
		key_direction -= 1.0
		
	if key_direction != 0.0:
		current_velocity = key_direction * max_pan_speed
		global_position.x += current_velocity * delta
		return 

	var target_direction = 0.0
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport_rect().size
	var safe_margin = max(edge_margin, 1.0)
	
	if mouse_pos.x >= screen_size.x - safe_margin:
		var depth = mouse_pos.x - (screen_size.x - safe_margin)
		target_direction = clamp(depth / safe_margin, 0.0, 1.0)
	elif mouse_pos.x <= safe_margin:
		var depth = safe_margin - mouse_pos.x
		target_direction = -clamp(depth / safe_margin, 0.0, 1.0)
		
	var target_velocity = target_direction * max_pan_speed
	current_velocity = lerp(current_velocity, target_velocity, edge_pan_acceleration * delta)
	global_position.x += current_velocity * delta

	if Input.is_key_pressed(KEY_Q):
		global_position.x = min_x_bound
	elif Input.is_key_pressed(KEY_E):
		global_position.x = max_x_bound
