extends CharacterBody2D

@export var speed = 200.0

func _ready() -> void:
	# Planes ignore ground physics completely
	collision_layer = 0
	collision_mask = 0

func _physics_process(delta: float) -> void:
	# Bypass move_and_slide, pure math movement
	global_position.x += speed * delta
