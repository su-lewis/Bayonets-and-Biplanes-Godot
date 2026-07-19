extends Camera2D

@export var max_pan_speed: float = 2500.0 
@export var edge_margin: float = 200.0 
@export var smoothing: float = 8.0 

var current_velocity: float = 0.0

func _ready() -> void:
	# Traps the mouse inside the game window so players can edge-pan 
	# without accidentally clicking on a second monitor!
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	
func _process(delta: float) -> void:
	var target_direction = 0.0
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport_rect().size
	
	# Prevent divide by zero error just in case margin is set to 0
	var safe_margin = max(edge_margin, 1.0)
	
	if mouse_pos.x >= screen_size.x - safe_margin:
		# Calculate how deep into the margin the mouse is (0.0 to 1.0)
		var depth = mouse_pos.x - (screen_size.x - safe_margin)
		target_direction = clamp(depth / safe_margin, 0.0, 1.0)
		
	elif mouse_pos.x <= safe_margin:
		# Calculate how deep into the margin the mouse is (0.0 to 1.0)
		var depth = safe_margin - mouse_pos.x
		target_direction = -clamp(depth / safe_margin, 0.0, 1.0)
		
	var target_velocity = target_direction * max_pan_speed
	
	# Smoothly glide the speed based on how far into the corner the mouse is
	current_velocity = lerp(current_velocity, target_velocity, smoothing * delta)
	
	global_position.x += current_velocity * delta
