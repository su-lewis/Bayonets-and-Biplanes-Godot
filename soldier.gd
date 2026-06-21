extends CharacterBody2D

const SPEED = 50.0

var target_lane_y: float = 0.0 
var target_scale: float = 1.0 
var base_scale: float = 1.0  
var start_x: float = 0.0
var walk_out_distance: float = 400.0 

var start_y_for_scale: float = 0.0 
var current_state: int = 0 

# --- NEW: Grab the Sprite node ---
@onready var sprite = $Sprite2D

func _ready():
	# Automatically remember whatever scale you set the Sprite2D to in the editor!
	base_scale = sprite.scale.x

func _physics_process(delta):
	if current_state == 0:
		# STATE 0: Walk out
		velocity.y = 0
		velocity.x = SPEED
		
		if global_position.x >= start_x + walk_out_distance:
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
				
			var total_y_distance = target_lane_y - start_y_for_scale
			if total_y_distance != 0:
				var current_y_distance = global_position.y - start_y_for_scale
				var progress = current_y_distance / total_y_distance
				
				var current_scale = lerp(base_scale, target_scale, progress)
				# --- FIXED: Only apply scale to the Sprite! ---
				sprite.scale = Vector2(current_scale, current_scale)
				
		else:
			global_position.y = target_lane_y
			# --- FIXED: Only apply final scale to the Sprite! ---
			sprite.scale = Vector2(target_scale, target_scale)
			current_state = 2 
			
	elif current_state == 2:
		# STATE 2: The Final March
		velocity.y = 0
		velocity.x = SPEED
		
	move_and_slide()
