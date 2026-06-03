extends CharacterBody2D

# Set the horizontal speed (adjust this number to your liking)
@export var speed = 150.0

func _physics_process(delta):
	# Apply only horizontal movement
	# In Godot, delta ensures smooth movement independent of framerate
	velocity.x = speed
	
	# Move the plane, but ignore ground collisions 
	# (We want it to fly, not land on people's heads!)
	move_and_slide()
