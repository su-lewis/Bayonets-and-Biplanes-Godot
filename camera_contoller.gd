extends Camera2D

@export var pan_speed: float = 1800.0 # How fast the camera flies across the map
@export var edge_margin: float = 300.0 # How close the mouse needs to be to the edge (in pixels)

func _process(delta):
	var direction = 0.0
	
	# Get the mouse position relative to the screen (the Viewport)
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport_rect().size
	
	# 1. Check if mouse is touching the RIGHT edge
	if mouse_pos.x >= screen_size.x - edge_margin:
		direction = 1.0
		
	# 2. Check if mouse is touching the LEFT edge
	elif mouse_pos.x <= edge_margin:
		direction = -1.0
		
	# Apply the movement! 
	# Godot's built-in "Limits" will automatically stop it from going past 0 or 6000.
	global_position.x += direction * pan_speed * delta
