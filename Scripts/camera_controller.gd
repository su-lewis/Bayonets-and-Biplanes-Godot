extends Camera2D

@export var pan_speed: float = 2000.0 
@export var edge_margin: float = 150.0 

func _physics_process(delta: float) -> void:
	var direction = 0.0
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport_rect().size
	
	if mouse_pos.x >= screen_size.x - edge_margin:
		direction = 1.0
	elif mouse_pos.x <= edge_margin:
		direction = -1.0
		
	global_position.x += direction * pan_speed * delta
