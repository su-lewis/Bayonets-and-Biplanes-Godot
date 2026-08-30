extends CharacterBody2D
class_name BaseUnit

enum State { ROLLOUT, DIAGONAL_PUSH, LANE_PUSH, ATTACK }
enum DamageType { BULLET, EXPLOSIVE, MELEE, FIRE }
enum ArmorType { UNARMORED, LIGHT, HEAVY, BUILDING }

@export var max_hp: float = 100.0
@export var damage: float = 20.0
@export var attack_cooldown: float = 1.0 
@export var move_speed: float = 50.0
@export var walk_out_distance: float = 120.0

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
	
	# Lock initial spawn position for rollout calculations
	start_x = global_position.x
	start_y_for_scale = global_position.y
	
	if sprite:
		base_scale = abs(sprite.scale.x)
	
	if is_enemy:
		move_dir = -1.0
		# THE FIX: Removed `if sprite: sprite.flip_h = true` to fix moonwalking bug
		
		if attack_range:
			for child in attack_range.get_children():
				if child is CollisionShape2D:
					child.position.x *= -1 
	else:
		move_dir = 1.0

# THE FIX: Safe scale logic that flips direction cleanly
func _set_sprite_scale(s: float) -> void:
	if not sprite: return
	var sign_x = -1.0 if is_enemy else 1.0
	sprite.scale = Vector2(s * sign_x, s)

func _find_target() -> void:
	if not attack_range: return
	
	for body in attack_range.get_overlapping_bodies():
		if body is BaseUnit and body != self and is_instance_valid(body) and not body.is_queued_for_deletion():
			var is_same_lane = abs(body.target_lane_y - self.target_lane_y) < 20.0
			var is_in_front = sign(body.global_position.x - self.global_position.x) == sign(move_dir)
			
			if body.is_enemy != self.is_enemy and is_same_lane and is_in_front:
				current_target = body
				return

func take_damage(amount: float, incoming_type: DamageType) -> void:
	var multiplier = _calculate_multiplier(incoming_type, armor_type)
	var final_damage = amount * multiplier
	current_hp -= final_damage
	
	if sprite:
		sprite.modulate = Color.RED
		var timer = get_tree().create_timer(0.1)
		timer.timeout.connect(func(): if is_instance_valid(sprite): sprite.modulate = Color.WHITE)
		
	if current_hp <= 0:
		queue_free() 

func _calculate_multiplier(dmg: DamageType, armor: ArmorType) -> float:
	match dmg:
		DamageType.BULLET:
			match armor:
				ArmorType.LIGHT: return 1.0
				ArmorType.HEAVY: return 0.15
		DamageType.EXPLOSIVE:
			match armor:
				ArmorType.LIGHT: return 2.0
				ArmorType.HEAVY: return 1.0
	return 1.0

func _physics_process(delta: float) -> void:
	# Clean up dead target references
	if is_instance_valid(current_target) and current_target.is_queued_for_deletion():
		current_target = null

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
			
			# Walk out of building first before turning toward lane
			if (not is_enemy and global_position.x >= start_x + walk_out_distance) or \
			   (is_enemy and global_position.x <= start_x - walk_out_distance):
				start_y_for_scale = global_position.y 
				current_state = State.DIAGONAL_PUSH
				
		State.DIAGONAL_PUSH:
			var y_diff = target_lane_y - global_position.y
			var vertical_speed = max(move_speed * 2.0, 200.0)
			
			# THE FIX: Clean lane snapping prevents tank oscillation/bouncing
			if abs(y_diff) <= vertical_speed * delta:
				global_position.y = target_lane_y
				_set_sprite_scale(target_scale)
				current_state = State.LANE_PUSH
			else:
				# Otherwise, move smoothly without the delta division jitter
				var y_vel = sign(y_diff) * vertical_speed
				velocity = Vector2(move_speed * move_dir, y_vel)
				
				# Smooth perspective scaling
				var total_y_dist = abs(target_lane_y - start_y_for_scale)
				if total_y_dist > 0.1:
					var current_y_dist = abs(global_position.y - start_y_for_scale)
					var progress = clamp(current_y_dist / total_y_dist, 0.0, 1.0)
					_set_sprite_scale(lerp(base_scale, target_scale, progress))
				
		State.LANE_PUSH:
			velocity = Vector2(move_speed * move_dir, 0)
			
			# THE FIX: No forced manual Y-position overriding here!
			_set_sprite_scale(target_scale)
			
			if sprite is AnimatedSprite2D and sprite.animation != "walk":
				sprite.play("walk")
				
		State.ATTACK:
			velocity = Vector2.ZERO 
			attack_timer -= delta
			
			if sprite is AnimatedSprite2D and sprite.animation != "aim":
				sprite.play("aim")
			
			if attack_timer <= 0.0:
				attack_timer = attack_cooldown
				if is_instance_valid(current_target):
					current_target.take_damage(damage, damage_type)

	move_and_slide()
