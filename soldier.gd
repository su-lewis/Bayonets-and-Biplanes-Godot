extends CharacterBody2D

const SPEED = 40.0
var gravity = 980 # Standard gravity force

func _physics_process(delta):
	# Add the gravity so the soldier stays on the ground
	if not is_on_floor():
		velocity.y += gravity * delta

	# Always move to the right
	velocity.x = SPEED

	# This handles the movement and stays on the slope
	move_and_slide()
