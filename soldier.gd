extends CharacterBody2D

const SPEED = 50.0

var target_lane_y: float = 0.0 
var target_scale: float = 0.15 # <--- Changed this from 1.0
var base_scale: float = 0.2   # <--- Added this to remember our starting size
var start_x: float = 0.0
var walk_out_distance: float = 80.0 

var start_y_for_scale: float = 0.0 # Remembers where we started the diagonal march

var current_state: int = 0 

func _physics_process(delta):
	if current_state == 0:
		# STATE 0: Walk out
		velocity.y = 0
		velocity.x = SPEED
		
		if global_position.x >= start_x + walk_out_distance:
			# The exact moment we turn diagonal, record our starting Y coordinate!
			start_y_for_scale = global_position.y 
			current_state = 1 
			
	elif current_state == 1:
		# STATE 1: The Diagonal March & Smooth Scaling
		var distance_to_lane = target_lane_y - global_position.y
		velocity.x = SPEED 
		
		if abs(distance_to_lane) > 2.0:
			if distance_to_lane > 0:
				velocity.y = SPEED * 0.8 
			else:
				velocity.y = -SPEED * 0.8 
				
			# --- THE NEW SMOOTH SCALE MATH ---
			# Calculate total distance vs distance traveled to get a percentage (0.0 to 1.0)
			var total_y_distance = target_lane_y - start_y_for_scale
			if total_y_distance != 0:
				var current_y_distance = global_position.y - start_y_for_scale
				var progress = current_y_distance / total_y_distance
				
				# lerp() smoothly blends from our exact starting size down to the target
				var current_scale = lerp(base_scale, target_scale, progress)
				scale = Vector2(current_scale, current_scale)
				
		else:
			global_position.y = target_lane_y
			scale = Vector2(target_scale, target_scale) # Snap exactly to final scale
			current_state = 2 
			
	elif current_state == 2:
		# STATE 2: The Final March
		velocity.y = 0
		velocity.x = SPEED
		
	move_and_slide()
