extends Camera2D

@export_category("Panning")
@export var max_pan_speed: float = 2500.0 
@export var edge_margin: float = 200.0 
@export var panning_smoothing: float = 8.0 

@export_category("Zooming")
@export var zoom_normal: float = 1.0       # The default zoom level
@export var zoom_out_max: float = 0.4      # How far spacebar zooms out (tweak this to fit your map!)
@export var zoom_in_max: float = 1.5       # The closest you can scroll in
@export var zoom_step: float = 0.1         # How much one tick of the mouse wheel zooms
@export var zoom_smoothing: float = 10.0   # How smooth the zoom transition feels

var current_velocity: float = 0.0
var target_zoom: float = 1.0

func _ready() -> void:
	# Traps the mouse inside the game window so players can edge-pan 
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	target_zoom = zoom.x # Initialize target to whatever the editor is set to

func _unhandled_input(event: InputEvent) -> void:
	# 1. Spacebar Toggle (Full Map vs Normal View)
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		# If we are currently zoomed out, snap back to normal. Otherwise, zoom all the way out.
		if abs(target_zoom - zoom_out_max) < 0.1:
			target_zoom = zoom_normal
		else:
			target_zoom = zoom_out_max

	# 2. Mouse Wheel Scroll (Incremental Zooming)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Scrolling UP zooms IN (increases the zoom vector)
			target_zoom = clamp(target_zoom + zoom_step, zoom_out_max, zoom_in_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Scrolling DOWN zooms OUT (decreases the zoom vector)
			target_zoom = clamp(target_zoom - zoom_step, zoom_out_max, zoom_in_max)

func _process(delta: float) -> void:
	# --- ZOOMING ---
	# Smoothly interpolate the camera's actual zoom toward our target_zoom
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), zoom_smoothing * delta)
	
	# --- PANNING ---
	var target_direction = 0.0
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport_rect().size
	
	# Prevent divide by zero error just in case margin is set to 0
	var safe_margin = max(edge_margin, 1.0)
	
	# Because mouse_pos is relative to the screen (not the world), 
	# zooming out does NOT break the edge panning!
	if mouse_pos.x >= screen_size.x - safe_margin:
		var depth = mouse_pos.x - (screen_size.x - safe_margin)
		target_direction = clamp(depth / safe_margin, 0.0, 1.0)
		
	elif mouse_pos.x <= safe_margin:
		var depth = safe_margin - mouse_pos.x
		target_direction = -clamp(depth / safe_margin, 0.0, 1.0)
		
	var target_velocity = target_direction * max_pan_speed
	
	# Smoothly glide the speed based on how far into the corner the mouse is
	current_velocity = lerp(current_velocity, target_velocity, panning_smoothing * delta)
	
	global_position.x += current_velocity * delta
