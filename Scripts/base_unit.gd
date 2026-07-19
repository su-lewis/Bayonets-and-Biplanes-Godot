extends CharacterBody2D
class_name BaseUnit

enum State { ROLLOUT, DIAGONAL_PUSH, LANE_PUSH }

@export var move_speed: float = 50.0
@export var walk_out_distance: float = 400.0

var target_lane_y: float = 0.0 
var target_scale: float = 1.0 
var base_scale: float = 1.0  
var start_x: float = 0.0
var start_y_for_scale: float = 0.0 

var current_state: State = State.ROLLOUT 
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	
	if sprite:
		base_scale = sprite.scale.x

func _physics_process(delta: float) -> void:
	match current_state:
		State.ROLLOUT:
			velocity = Vector2(move_speed, 0)
			
			if global_position.x >= start_x + walk_out_distance:
				start_y_for_scale = global_position.y 
				current_state = State.DIAGONAL_PUSH
				
		State.DIAGONAL_PUSH:
			var distance_to_lane = target_lane_y - global_position.y
			
			# Smooth Scaling
			var total_y_distance = target_lane_y - start_y_for_scale
			if total_y_distance != 0:
				var current_y_distance = global_position.y - start_y_for_scale
				var progress = clamp(abs(current_y_distance) / abs(total_y_distance), 0.0, 1.0)
				var current_scale = lerp(base_scale, target_scale, progress)
				if sprite:
					sprite.scale = Vector2(current_scale, current_scale)
			
			var move_dir = Vector2(1.0, 0.8 * sign(distance_to_lane)).normalized()
			var y_step_this_frame = abs(move_dir.y * move_speed) * delta
			
			# JITTER FIX: Overshoot snap
			if abs(distance_to_lane) <= y_step_this_frame:
				current_state = State.LANE_PUSH
			else:
				velocity = move_dir * move_speed
				
		State.LANE_PUSH:
			velocity = Vector2(move_speed, 0)
			# FORCE LOCK the Y-axis and Scale so it stops jittering/drifting!
			global_position.y = target_lane_y
			if sprite:
				sprite.scale = Vector2(target_scale, target_scale)

	move_and_slide()
