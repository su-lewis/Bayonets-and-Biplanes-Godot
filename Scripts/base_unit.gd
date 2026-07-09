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
	# PHYSICS SETUP:
	# collision_layer = 2 (I am a Unit)
	# collision_mask = 1 (I bump into Environment/Craters on layer 1, but NOT other units on layer 2)
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
			var y_step_this_frame = (move_speed * 0.8) * delta
			
			# JITTER FIX: If we are going to overshoot the lane this frame, snap perfectly to it.
			if abs(distance_to_lane) <= y_step_this_frame:
				global_position.y = target_lane_y
				velocity = Vector2(move_speed, 0)
				current_state = State.LANE_PUSH
			else:
				velocity.x = move_speed
				velocity.y = (move_speed * 0.8) * sign(distance_to_lane)
			
			# Smooth Scaling
			var total_y_distance = target_lane_y - start_y_for_scale
			if total_y_distance != 0:
				var current_y_distance = global_position.y - start_y_for_scale
				var progress = clamp(abs(current_y_distance) / abs(total_y_distance), 0.0, 1.0)
				var current_scale = lerp(base_scale, target_scale, progress)
				if sprite:
					sprite.scale = Vector2(current_scale, current_scale)
					
		State.LANE_PUSH:
			velocity = Vector2(move_speed, 0)

	# Apply Godot's physics (allowing interaction with craters/holes)
	move_and_slide()
