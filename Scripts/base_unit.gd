extends CharacterBody2D
class_name BaseUnit

enum State { ROLLOUT, DIAGONAL_PUSH, LANE_PUSH, ATTACK }

# --- COMBAT STATS (Tweak these in the Inspector for each unit!) ---
@export var max_hp: float = 100.0
@export var damage: float = 20.0
@export var attack_cooldown: float = 1.0 # Attacks once per second
@export var move_speed: float = 50.0
@export var walk_out_distance: float = 400.0

var current_hp: float = 100.0
var is_enemy: bool = false
var move_dir: float = 1.0 # 1.0 for player (Right), -1.0 for enemy (Left)

var target_lane_y: float = 0.0 
var target_scale: float = 1.0 
var base_scale: float = 1.0  
var start_x: float = 0.0
var start_y_for_scale: float = 0.0 

var current_state: State = State.ROLLOUT 

# --- COMBAT VARIABLES ---
var attack_timer: float = 0.0
var current_target: Node2D = null
var detection_area: Area2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Tell Godot this is top-down/2.5D, not a platformer
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	collision_layer = 2
	collision_mask = 1
	
	current_hp = max_hp
	
	# If this is an enemy, reverse their direction and flip the art!
	if is_enemy:
		move_dir = -1.0
		if sprite:
			sprite.flip_h = true
	else:
		move_dir = 1.0
	
	if sprite:
		base_scale = sprite.scale.x

	_setup_vision_cone()

# We build the hitbox in code so you don't have to use the Editor!
func _setup_vision_cone() -> void:
	detection_area = Area2D.new()
	detection_area.collision_layer = 0
	detection_area.collision_mask = 2 # Only look for other Units (Layer 2)
	add_child(detection_area)
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	
	# Large hitbox so even big units in the bottom lane can see each other
	rect.size = Vector2(250, 60) 
	shape.shape = rect
	
	# Place the box in front of the unit based on which way they are walking
	shape.position = Vector2(125 * move_dir, 0)
	detection_area.add_child(shape)
	
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is BaseUnit and body != self:
		
		# FLOATING POINT FIX: Check if they are within 5 pixels of the same lane
		var is_same_lane = abs(body.target_lane_y - self.target_lane_y) < 5.0
		
		# COMBAT CHECK: Are they an enemy? AND are they in the exact same lane?
		if body.is_enemy != self.is_enemy and is_same_lane:
			if current_target == null:
				current_target = body

func _on_body_exited(body: Node2D) -> void:
	if body == current_target:
		current_target = null
		_find_new_target()

func _find_new_target() -> void:
	for body in detection_area.get_overlapping_bodies():
		if body is BaseUnit and body != self:
			var is_same_lane = abs(body.target_lane_y - self.target_lane_y) < 5.0
			
			if body.is_enemy != self.is_enemy and is_same_lane:
				current_target = body
				return

func take_damage(amount: float) -> void:
	current_hp -= amount
	
	# Give them a little flash effect when hit
	if sprite:
		sprite.modulate = Color.RED
		var timer = get_tree().create_timer(0.1)
		timer.timeout.connect(func(): if sprite: sprite.modulate = Color.WHITE)
		
	if current_hp <= 0:
		queue_free() # Unit dies and is deleted!

func _physics_process(delta: float) -> void:
	# Check if we should stop walking and start attacking
	if is_instance_valid(current_target) and current_state == State.LANE_PUSH:
		current_state = State.ATTACK

	# If our target dies while we are attacking, resume walking!
	if current_state == State.ATTACK and not is_instance_valid(current_target):
		current_state = State.LANE_PUSH
		_find_new_target() 

	match current_state:
		State.ROLLOUT:
			velocity = Vector2(move_speed * move_dir, 0)
			
			# Check walk out distance (handles both right-moving players and left-moving enemies)
			if (not is_enemy and global_position.x >= start_x + walk_out_distance) or \
			   (is_enemy and global_position.x <= start_x - walk_out_distance):
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
			
			# Normalize the diagonal vector so diagonal speed equals forward speed
			var move_vector = Vector2(move_dir, 0.8 * sign(distance_to_lane)).normalized()
			var y_step_this_frame = abs(move_vector.y * move_speed) * delta
			
			# JITTER FIX: Overshoot snap
			if abs(distance_to_lane) <= y_step_this_frame:
				current_state = State.LANE_PUSH
			else:
				velocity = move_vector * move_speed
				
		State.LANE_PUSH:
			velocity = Vector2(move_speed * move_dir, 0)
			
			# FORCE LOCK the Y-axis and Scale so it stops jittering/drifting!
			global_position.y = target_lane_y
			if sprite:
				sprite.scale = Vector2(target_scale, target_scale)
				
		State.ATTACK:
			velocity = Vector2.ZERO # Stop walking!
			attack_timer -= delta
			
			if attack_timer <= 0.0:
				attack_timer = attack_cooldown
				if is_instance_valid(current_target):
					current_target.take_damage(damage)

	move_and_slide()
