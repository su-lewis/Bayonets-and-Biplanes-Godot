extends Camera2D

@export_category("Panning")
@export var max_pan_speed: float = 2500.0 
@export var edge_margin: float = 200.0 
@export var edge_pan_acceleration: float = 15.0

@export_category("Zooming")
@export var zoom_default: float = 0.6         # Your main, zoomed-out view
@export var zoom_in_level: float = 1.0        # Your zoomed-in toggle view
@export var world_bottom_edge: float = 1080.0 # The absolute lowest Y-coordinate of your mud/trench
@export var ui_panel_height: float = 90.0    # Set this to the exact pixel height of your UI

var current_velocity: float = 0.0
var is_zoomed_in: bool = false                # Flipped the logic: we now track if we are zoomed IN

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	# Start the game in the zoomed-out view
	zoom = Vector2(zoom_default, zoom_default)
	_align_camera_y(zoom_default)

func _input(event: InputEvent) -> void:
	# Spacebar Toggle 
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		is_zoomed_in = !is_zoomed_in
		
		var target_zoom = zoom_in_level if is_zoomed_in else zoom_default
		zoom = Vector2(target_zoom, target_zoom)
		_align_camera_y(target_zoom)

# --- THE PERFECTED MATH ---
func _align_camera_y(current_zoom: float) -> void:
	var viewport_height = get_viewport_rect().size.y
	
	# Calculate the distance from the center of the monitor down to the top of your UI
	var screen_center_to_ui_top = (viewport_height / 2.0) - ui_panel_height
	
	# Lock the camera so your world's bottom edge never dips below the UI line
	global_position.y = world_bottom_edge - (screen_center_to_ui_top / current_zoom)

func _process(delta: float) -> void:
	# --- EDGE PANNING ---
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
