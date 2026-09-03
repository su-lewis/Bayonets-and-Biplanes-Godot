extends Camera2D

@export_category("Panning")
@export var max_pan_speed: float = 2500.0 
@export var edge_margin: float = 200.0 
@export var edge_pan_acceleration: float = 15.0

@export_category("Zooming")
@export var zoom_normal: float = 1.0       
@export var zoom_out_max: float = 0.4      
@export var zoom_in_max: float = 1.5       
@export var zoom_step: float = 0.1         

var current_velocity: float = 0.0
var is_dragging: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

func _unhandled_input(event: InputEvent) -> void:
	# 1. Spacebar Toggle 
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		if abs(zoom.x - zoom_out_max) < 0.01:
			zoom = Vector2(zoom_normal, zoom_normal)
		else:
			zoom = Vector2(zoom_out_max, zoom_out_max)

	# 2. Left Click Drag Toggle
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed

	# 3. Drag Panning (1:1 Instant Snap)
	if event is InputEventMouseMotion and is_dragging:
		global_position -= event.relative / zoom.x

	# 4. Mouse Wheel Scroll (Flawless Pointer Zoom Math)
	if event is InputEventMouseButton and event.pressed:
		var new_zoom = zoom.x
		var zoom_changed = false
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			new_zoom = clamp(zoom.x + zoom_step, zoom_out_max, zoom_in_max)
			zoom_changed = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			new_zoom = clamp(zoom.x - zoom_step, zoom_out_max, zoom_in_max)
			zoom_changed = true

		if zoom_changed and new_zoom != zoom.x:
			# Capturing the world coordinates before the engine updates
			var mouse_world = get_global_mouse_position()
			var cam_center = get_screen_center_position()
			
			# The distance from the center of the screen to the mouse
			var offset = mouse_world - cam_center
			var zoom_ratio = zoom.x / new_zoom
			
			# Apply zoom instantly
			zoom = Vector2(new_zoom, new_zoom) 
			
			# Manually shift the camera by the exact pixel difference
			global_position += offset * (1.0 - zoom_ratio) 

func _process(delta: float) -> void:
	# --- EDGE PANNING ---
	if is_dragging:
		current_velocity = 0.0
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
