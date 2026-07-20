extends CharacterBody2D
class_name BaseUnit

enum State { ROLLOUT, DIAGONAL_PUSH, LANE_PUSH, ATTACK }

# --- NEW ENUMS FOR STRATEGY MATRIX ---
enum DamageType { BULLET, EXPLOSIVE }
enum ArmorType { LIGHT, HEAVY }

# --- COMBAT STATS (Tweak these in the Inspector!) ---
@export var max_hp: float = 100.0
@export var damage: float = 20.0
@export var attack_cooldown: float = 1.0 
@export var move_speed: float = 50.0
@export var walk_out_distance: float = 400.0

# --- NEW EXPORTS ---
@export var armor_type: ArmorType = ArmorType.LIGHT
@export var damage_type: DamageType = DamageType.BULLET

var current_hp: float = 100.0
var is_enemy: bool = false
var move_dir: float = 1.0 

var target_lane_y: float = 0.0 
var target_scale: float = 1.0 
var base_scale: float = 1.0  
var start_x: float = 0.0
var start_y_for_scale: float = 0.0 

var current_state: State = State.ROLLOUT 
var attack_timer: float = 0.0
var current_target: Node2D = null

@onready var sprite = $Sprite2D
@onready var attack_range: Area2D = $AttackRange 

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	current_hp = max_hp
	
	if is_enemy:
		move_dir = -1.0
		if sprite:
			sprite.flip_h = true
		if attack_range:
			for child in attack_range.get_children():
				if child is CollisionShape2D:
					child.position.x *= -1 
	else:
		move_dir = 1.0
	
	if sprite:
		base_scale = sprite.scale.x

func _find_target() -> void:
	if not attack_range: return
	
	for body in attack_range.get_overlapping_bodies():
		if body is BaseUnit and body != self:
			var is_same_lane = abs(body.target_lane_y - self.target_lane_y) < 5.0
			var is_in_front = sign(body.global_position.x - self.global_position.x) == sign(move_dir)
			
			if body.is_enemy != self.is_enemy and is_same_lane and is_in_front:
				current_target = body
				return

# --- UPDATED TO ACCEPT DAMAGE TYPE ---
func take_damage(amount: float, incoming_type: DamageType) -> void:
	var multiplier = _calculate_multiplier(incoming_type, armor_type)
	var final_damage = amount * multiplier
	
	current_hp -= final_damage
	
	if sprite:
		sprite.modulate = Color.RED
		var timer = get_tree().create_timer(0.1)
		timer.timeout.connect(func(): if sprite: sprite.modulate = Color.WHITE)
		
	if current_hp <= 0:
		queue_free() 

# --- THE STRATEGY MATRIX ---
func _calculate_multiplier(dmg: DamageType, armor: ArmorType) -> float:
	match dmg:
		DamageType.BULLET:
			match armor:
				ArmorType.LIGHT: return 1.0   # Bullets vs Infantry (Normal)
				ArmorType.HEAVY: return 0.15  # Bullets vs Tanks (Ineffective - 85% reduction!)
		DamageType.EXPLOSIVE:
			match armor:
				ArmorType.LIGHT: return 2.0   # Explosives vs Infantry (Devastating - Double damage!)
				ArmorType.HEAVY: return 1.0   # Explosives vs Tanks (Normal)
	return 1.0

func _physics_process(delta: float) -> void:
	if current_state == State.LANE_PUSH:
		if not is_instance_valid(current_target):
			_find_target() 
		else:
			current_state = State.ATTACK 

	if current_state == State.ATTACK and not is_instance_valid(current_target):
		current_state = State.LANE_PUSH

	match current_state:
		State.ROLLOUT:
			velocity = Vector2(move_speed * move_dir, 0)
			
			if (not is_enemy and global_position.x >= start_x + walk_out_distance) or \
			   (is_enemy and global_position.x <= start_x - walk_out_distance):
				start_y_for_scale = global_position.y 
				current_state = State.DIAGONAL_PUSH
				
		State.DIAGONAL_PUSH:
			var distance_to_lane = target_lane_y - global_position.y
			
			var total_y_distance = target_lane_y - start_y_for_scale
			if total_y_distance != 0:
				var current_y_distance = global_position.y - start_y_for_scale
				var progress = clamp(abs(current_y_distance) / abs(total_y_distance), 0.0, 1.0)
				var current_scale = lerp(base_scale, target_scale, progress)
				if sprite:
					sprite.scale = Vector2(current_scale, current_scale)
			
			var move_vector = Vector2(move_dir, 2.5 * sign(distance_to_lane)).normalized()
			var y_step_this_frame = abs(move_vector.y * move_speed) * delta
			
			if abs(distance_to_lane) <= max(y_step_this_frame, 15.0):
				current_state = State.LANE_PUSH
			else:
				velocity = move_vector * move_speed
				
		State.LANE_PUSH:
			velocity = Vector2(move_speed * move_dir, 0)
			global_position.y = target_lane_y
			if sprite:
				sprite.scale = Vector2(target_scale, target_scale)
				# Only play the walk animation if the sprite is actually animated!
				if sprite is AnimatedSprite2D:
					sprite.play("walk")
				
		State.ATTACK:
			velocity = Vector2.ZERO 
			attack_timer -= delta
			
			# Only play the aim animation if the sprite is actually animated!
			if sprite is AnimatedSprite2D:
				sprite.play("aim")
			
			if attack_timer <= 0.0:
				attack_timer = attack_cooldown
				if is_instance_valid(current_target):
					current_target.take_damage(damage, damage_type)

	move_and_slide()
