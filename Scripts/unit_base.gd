extends CharacterBody2D
class_name BaseUnit

enum State { ROLLOUT, DIAGONAL_PUSH, LANE_PUSH, ATTACK }

@export var data: UnitData 

var current_hp: float
var is_enemy: bool = false
var move_dir: float = 1.0 
var lane_id: int = 0
var current_state: State = State.ROLLOUT 

# Weapon Tracking
var weapon_cooldowns: Dictionary = {}
var current_target: BaseUnit = null

var target_lane_y: float = 0.0 
var target_scale: float = 1.0 
var base_scale: float = 1.0  
var start_x: float = 0.0
var start_y_for_scale: float = 0.0 

@onready var sprite = $Sprite2D

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	current_hp = data.max_hp
	start_x = global_position.x
	start_y_for_scale = global_position.y
	if sprite: base_scale = abs(sprite.scale.x)
	move_dir = -1.0 if is_enemy else 1.0
	add_to_group("enemy_units" if is_enemy else "player_units")
	
	# Initialize all weapon cooldowns to 0
	for weapon in data.weapons:
		weapon_cooldowns[weapon] = 0.0

func _set_sprite_scale(s: float) -> void:
	if not sprite: return
	sprite.scale = Vector2(s * (-1.0 if is_enemy else 1.0), s)

func take_damage(amount: float, pen_mm: float, is_vital: bool) -> void:
	var actual_damage = CombatResolver.calculate_damage(amount, pen_mm, data.armor_thickness_mm, is_vital)
	
	if actual_damage > 0:
		current_hp -= actual_damage
		if sprite:
			sprite.modulate = Color.RED
			get_tree().create_timer(0.1).timeout.connect(func(): if is_instance_valid(sprite): sprite.modulate = Color.WHITE)
			
	if current_hp <= 0:
		queue_free()

func _find_target() -> void:
	var enemy_group = "player_units" if is_enemy else "enemy_units"
	var closest_enemy: BaseUnit = null
	
	# Find max range among all equipped weapons
	var max_range: float = 0.0
	for w in data.weapons:
		if w.attack_range > max_range: max_range = w.attack_range
		
	var closest_dist: float = max_range
	
	for enemy in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue
		if enemy.data.is_flying != self.data.is_flying: continue 
		if not data.is_flying and enemy.lane_id != self.lane_id: continue 
			
		var dist_in_front = (enemy.global_position.x - global_position.x) * move_dir
		if dist_in_front > 0.0 and dist_in_front <= closest_dist:
			closest_dist = dist_in_front
			closest_enemy = enemy
			
	current_target = closest_enemy

func _fire_weapons() -> void:
	if not is_instance_valid(current_target): return
	var dist = abs(current_target.global_position.x - global_position.x)
	var is_moving = (current_state != State.ATTACK)
	
	for weapon in data.weapons:
		if weapon_cooldowns[weapon] <= 0.0 and dist <= weapon.attack_range:
			weapon_cooldowns[weapon] = weapon.fire_rate
			
			# Accuracy Math
			var hit_chance = weapon.base_accuracy
			if is_moving: hit_chance -= weapon.moving_accuracy_penalty
			
			var dice_roll = randf()
			var is_hit = dice_roll <= hit_chance
			var is_vital = dice_roll <= weapon.vital_hit_chance
			
			_spawn_tracer(current_target, is_hit)
			
			if is_hit:
				current_target.take_damage(weapon.damage, weapon.penetration_mm, is_vital)

func _spawn_tracer(target: BaseUnit, is_hit: bool) -> void:
	var tracer = Line2D.new()
	tracer.width = 1.0
	tracer.default_color = Color(1.0, 0.9, 0.5, 0.8) # Faint yellow flash
	
	# Start at the gun barrel (approximate center of sprite)
	var start_pos = global_position + Vector2(10 * move_dir, -10)
	var end_pos = target.global_position + Vector2(0, -10)
	
	# If missed, visibly deflect the bullet into the dirt or over their head
	if not is_hit:
		var miss_y = randf_range(-40.0, 40.0) 
		var miss_x = randf_range(20.0, 50.0) * move_dir
		end_pos += Vector2(miss_x, miss_y)
		
	tracer.add_point(start_pos)
	tracer.add_point(end_pos)
	get_tree().current_scene.add_child(tracer)
	
	# Instantly fade the tracer out in 0.1 seconds to fake high velocity
	var tween = create_tween()
	tween.tween_property(tracer, "modulate:a", 0.0, 0.1)
	tween.tween_callback(tracer.queue_free)

func _physics_process(delta: float) -> void:
	# Tick down all weapon cooldowns
	for weapon in weapon_cooldowns.keys():
		if weapon_cooldowns[weapon] > 0.0:
			weapon_cooldowns[weapon] -= delta

	# (Keep your existing airplane, target-finding, and movement state machine code here EXACTLY as it was)
	
	if data.is_flying:
		global_position.x += (data.move_speed * move_dir) * delta
		return 

	if is_instance_valid(current_target) and current_target.is_queued_for_deletion():
		current_target = null

	if current_state == State.LANE_PUSH:
		if not is_instance_valid(current_target):
			_find_target()
		else:
			current_state = State.ATTACK 

	if current_state == State.ATTACK:
		if not is_instance_valid(current_target):
			current_state = State.LANE_PUSH
		else:
			var dist = (current_target.global_position.x - global_position.x) * move_dir
			# Check if target is out of the LONGEST weapon range
			var max_range: float = 0.0
			for w in data.weapons:
				if w.attack_range > max_range: max_range = w.attack_range
			
			if dist < 0.0 or dist > max_range:
				current_target = null
				current_state = State.LANE_PUSH
			else:
				_fire_weapons() # FIRE ALL READY WEAPONS

	match current_state:
		State.ROLLOUT:
			velocity = Vector2(data.move_speed * move_dir, 0)
			if (not is_enemy and global_position.x >= start_x + data.walk_out_distance) or \
			   (is_enemy and global_position.x <= start_x - data.walk_out_distance):
				start_y_for_scale = global_position.y 
				current_state = State.DIAGONAL_PUSH
				
		State.DIAGONAL_PUSH:
			var y_diff = target_lane_y - global_position.y
			var vertical_speed = max(data.move_speed * 2.0, 200.0)
			
			if abs(y_diff) <= vertical_speed * delta:
				global_position.y = target_lane_y
				_set_sprite_scale(target_scale)
				current_state = State.LANE_PUSH
			else:
				velocity = Vector2(data.move_speed * move_dir, sign(y_diff) * vertical_speed)
				var total_y_dist = abs(target_lane_y - start_y_for_scale)
				if total_y_dist > 0.1:
					var progress = clamp(abs(global_position.y - start_y_for_scale) / total_y_dist, 0.0, 1.0)
					_set_sprite_scale(lerp(base_scale, target_scale, progress))
				
		State.LANE_PUSH:
			velocity = Vector2(data.move_speed * move_dir, 0)
			_set_sprite_scale(target_scale)
			if sprite is AnimatedSprite2D and sprite.animation != "walk":
				sprite.play("walk")
			
			# Optional: Allow firing on the move if target is valid
			if is_instance_valid(current_target): _fire_weapons()
				
		State.ATTACK:
			velocity = Vector2.ZERO 
			if sprite is AnimatedSprite2D and sprite.animation != "aim":
				sprite.play("aim")

	move_and_slide()
