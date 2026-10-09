extends CharacterBody2D
class_name BaseUnit

enum State { ROLLOUT, DIAGONAL_PUSH, LANE_PUSH, ATTACK, MOVE_TO_BUILD, DIGGING, GARRISONED }

@export var data: UnitData

var current_hp: float
var is_enemy: bool = false
var move_dir: float = 1.0
var lane_id: int = 0
var current_state: State = State.ROLLOUT

var weapon_cooldowns: Dictionary = {}
var current_target: BaseUnit = null

var target_lane_y: float = 0.0
var target_scale: float = 1.0
var base_scale: float = 1.0
var start_x: float = 0.0
var start_y_for_scale: float = 0.0

# --- SAPPER VARIABLES ---
var is_sapper: bool = false
var build_target_x: float = 0.0
var built_trench: Node2D = null

# --- TRUE RIGID BODY VARIABLES ---
var ground_node: Polygon2D = null
var track_node: Node2D = null
var vertical_velocity: float = 0.0
var angular_velocity: float = 0.0
var current_traction: float = 1.0
var current_mud_sink_ratio: float = 0.0
var is_physically_stable: bool = true
var gravity: float = 980.0

# --- OPTIMIZATION VARIABLES ---
var search_timer: float = 0.0
var cached_poly: PackedVector2Array = []
var tread_threshold: float = 0.0
var cached_contact_fwd: float = 0.0
var cached_contact_bwd: float = 0.0

@onready var sprite = $Sprite2D

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	current_hp = data.max_hp
	start_x = global_position.x
	start_y_for_scale = global_position.y

	if sprite: 
		base_scale = abs(sprite.scale.x)
		if is_equal_approx(target_scale, 1.0):
			target_scale = base_scale
		
	move_dir = -1.0 if is_enemy else 1.0
	add_to_group("enemy_units" if is_enemy else "player_units")

	for weapon in data.weapons:
		weapon_cooldowns[weapon] = 0.0
		
	if is_sapper:
		current_state = State.MOVE_TO_BUILD
		
	track_node = _get_track_shape()
	if track_node:
		if is_enemy:
			var flipped_poly = PackedVector2Array()
			for pt in track_node.polygon:
				flipped_poly.append(Vector2(-pt.x, pt.y))
			track_node.polygon = flipped_poly
			
		var old_rot = sprite.rotation
		var old_scale = sprite.scale
		sprite.rotation = 0.0
		sprite.scale = Vector2.ONE
		
		sprite.force_update_transform()
		if track_node is Node2D: track_node.force_update_transform()
		
		var lowest_y = -99999.0
		for pt in track_node.polygon:
			var global_pt = track_node.to_global(pt)
			var local_pt = self.to_local(global_pt)
			cached_poly.append(local_pt)
			if local_pt.y > lowest_y: lowest_y = local_pt.y
			
		tread_threshold = lowest_y - 25.0 
		cached_contact_fwd = -99999.0
		cached_contact_bwd = 99999.0
		
		for pt in cached_poly:
			var true_x = pt.x * move_dir
			if pt.y >= tread_threshold:
				if true_x > cached_contact_fwd: cached_contact_fwd = true_x
				if true_x < cached_contact_bwd: cached_contact_bwd = true_x
				
		sprite.rotation = old_rot
		sprite.scale = old_scale
		
	if data.is_vehicle or is_sapper:
		var parent_lane = get_parent()
		if parent_lane and parent_lane.has_node("DestructibleGround"):
			ground_node = parent_lane.get_node("DestructibleGround")

func _get_track_shape() -> Node2D:
	if sprite:
		for child in sprite.get_children():
			if child is CollisionPolygon2D or child is Polygon2D:
				return child
	for child in get_children():
		if child is CollisionPolygon2D or child is Polygon2D:
			return child
	return null

func _set_sprite_scale(s: float) -> void:
	if not sprite: return
	sprite.scale = Vector2(s, s)
	if sprite is Sprite2D or sprite is AnimatedSprite2D:
		sprite.flip_h = is_enemy

func take_damage(amount: float, pen_mm: float, is_vital: bool) -> void:
	var actual_damage = CombatResolver.calculate_damage(amount, pen_mm, data.armor_thickness_mm, is_vital)
	
	if current_state == State.GARRISONED:
		actual_damage *= 0.5 # Sappers get 50% damage reduction in trenches!
		
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
	var is_moving = (current_state != State.ATTACK and current_state != State.GARRISONED)
	
	for weapon in data.weapons:
		if weapon_cooldowns[weapon] <= 0.0 and dist <= weapon.attack_range:
			weapon_cooldowns[weapon] = weapon.fire_rate
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
	tracer.default_color = Color(1.0, 0.9, 0.5, 0.8)
	var start_pos = global_position + Vector2(10 * move_dir, -10)
	var end_pos = target.global_position + Vector2(0, -10)
	
	if not is_hit:
		var miss_y = randf_range(-40.0, 40.0) 
		var miss_x = randf_range(20.0, 50.0) * move_dir
		end_pos += Vector2(miss_x, miss_y)
		
	tracer.add_point(start_pos)
	tracer.add_point(end_pos)
	get_tree().current_scene.add_child(tracer)
	var tween = create_tween()
	tween.tween_property(tracer, "modulate:a", 0.0, 0.1)
	tween.tween_callback(tracer.queue_free)

func _physics_process(delta: float) -> void:
	if search_timer > 0.0: search_timer -= delta
	for weapon in weapon_cooldowns.keys():
		if weapon_cooldowns[weapon] > 0.0: weapon_cooldowns[weapon] -= delta

	if data.is_flying:
		global_position.x += (data.move_speed * move_dir) * delta
		return 

	if is_instance_valid(current_target) and current_target.is_queued_for_deletion():
		current_target = null

	if current_state in [State.LANE_PUSH, State.GARRISONED]:
		if not is_instance_valid(current_target):
			if search_timer <= 0.0:
				_find_target()
				search_timer = 0.25 
		else:
			if current_state != State.GARRISONED:
				current_state = State.ATTACK 

	if current_state == State.ATTACK:
		if not is_instance_valid(current_target):
			current_state = State.LANE_PUSH
		else:
			var dist = (current_target.global_position.x - global_position.x) * move_dir
			var max_range: float = 0.0
			for w in data.weapons:
				if w.attack_range > max_range: max_range = w.attack_range
			if dist < 0.0 or dist > max_range:
				current_target = null
				current_state = State.LANE_PUSH
			else:
				_fire_weapons()

	match current_state:
		State.ROLLOUT:
			velocity = Vector2(data.move_speed * move_dir, 0)
			if (not is_enemy and global_position.x >= start_x + data.walk_out_distance) or \
			   (is_enemy and global_position.x <= start_x - data.walk_out_distance):
				start_y_for_scale = global_position.y 
				if is_sapper:
					current_state = State.MOVE_TO_BUILD
				else:
					current_state = State.LANE_PUSH if data.is_vehicle else State.DIAGONAL_PUSH
				
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
			if data.is_vehicle:
				var pitch_angle = sprite.rotation * move_dir
				var slope_gravity = sin(pitch_angle) * data.weight_tons * 15.0 
				
				# Only apply mud drag on flat ground! Steep hills need full engine power.
				var mud_drag = 1.0
				if pitch_angle > -0.2: 
					mud_drag = 1.0 - (current_mud_sink_ratio * 0.4)
				
				var net_forward = (data.engine_power * current_traction * mud_drag) + slope_gravity
				var final_speed = clamp(net_forward, -data.move_speed * 0.5, data.move_speed)
				
				# THE CRAWLER GEAR: Fixes the Stall-Out bug entirely!
				if final_speed < (data.move_speed * 0.2) and current_traction >= 0.5:
					final_speed = data.move_speed * 0.2
				
				var horizontal_speed = final_speed * cos(sprite.rotation)
				velocity = Vector2(horizontal_speed * move_dir, 0.0)
			else:
				velocity = Vector2(data.move_speed * move_dir, 0)
				
			_set_sprite_scale(target_scale)
			if sprite is AnimatedSprite2D and sprite.animation != "walk":
				sprite.play("walk")
			if is_instance_valid(current_target): _fire_weapons()
				
		State.ATTACK:
			velocity = Vector2.ZERO 
			if sprite is AnimatedSprite2D and sprite.animation != "aim":
				sprite.play("aim")

		# --- SAPPER STATES ---
		State.MOVE_TO_BUILD:
			velocity = Vector2(data.move_speed * move_dir, 0)
			_set_sprite_scale(target_scale)
			if sprite is AnimatedSprite2D and sprite.animation != "walk":
				sprite.play("walk")
				
			if search_timer <= 0.0:
				_find_target()
				search_timer = 0.25 
			if is_instance_valid(current_target): _fire_weapons()
				
			var dist_to_target = (build_target_x - global_position.x) * move_dir
			if dist_to_target <= 5.0:
				current_state = State.DIGGING
				if sprite is AnimatedSprite2D: sprite.play("dig")
				
		State.DIGGING:
			velocity = Vector2.ZERO
			if is_instance_valid(ground_node):
				var is_done = ground_node.carve_trench_step(global_position.x, 30, 20, 40.0, 20.0 * delta)
				if built_trench:
					built_trench.modulate.a = min(built_trench.modulate.a + (1.5 * delta), 1.0)
				if is_done:
					current_state = State.GARRISONED
					
		State.GARRISONED:
			velocity = Vector2.ZERO
			if is_instance_valid(current_target): 
				_fire_weapons()
				if sprite is AnimatedSprite2D and sprite.animation != "aim": sprite.play("aim")
			else:
				if sprite is AnimatedSprite2D and sprite.animation != "idle": sprite.play("idle")

	move_and_slide()

	if data.is_vehicle and is_instance_valid(ground_node):
		_apply_vehicle_physics(delta)


# --- TRUE RIGID BODY SIMULATOR (YOUR EXACT PASTED PHYSICS) ---
func _apply_vehicle_physics(delta: float) -> void:
	if cached_poly.is_empty() or not ground_node: return

	var buffer = 10.0 * target_scale

	# 1. KINEMATIC MOMENTUM
	vertical_velocity += gravity * delta
	global_position.y += vertical_velocity * delta
	sprite.rotation += angular_velocity * delta

	# 2. CONTINUOUS DYNAMIC SENSORS 
	var max_tread_pen = -9999.0
	var max_bumper_pen = -9999.0

	var max_f_pen = -9999.0
	var max_b_pen = -9999.0
	var f_contact_pos = Vector2.ZERO
	var b_contact_pos = Vector2.ZERO
	
	var contact_pts = 0

	for pt in cached_poly:
		var scaled_pt = pt * target_scale
		var rotated_pt = scaled_pt.rotated(sprite.rotation)
		var global_x = global_position.x + rotated_pt.x
		var global_y = global_position.y + rotated_pt.y
		var local_x = ground_node.to_local(Vector2(global_x, 0)).x
		var dirt_y = ground_node.to_global(Vector2(0, ground_node.get_exact_height(local_x))).y
		
		var penetration = global_y - dirt_y
		var true_x = pt.x * move_dir
		
		if pt.y >= tread_threshold: 
			if penetration > max_tread_pen: 
				max_tread_pen = penetration
				
			if true_x > 0:
				if penetration > max_f_pen:
					max_f_pen = penetration
					f_contact_pos = Vector2(global_x, dirt_y)
			else:
				if penetration > max_b_pen:
					max_b_pen = penetration
					b_contact_pos = Vector2(global_x, dirt_y)
		else:
			if true_x > cached_contact_fwd: 
				if penetration > max_bumper_pen: 
					max_bumper_pen = penetration

	# Engine Mud Drag Tracker
	if max_tread_pen > 0.0:
		current_mud_sink_ratio = clamp(max_tread_pen / buffer, 0.0, 1.0)
	else:
		current_mud_sink_ratio = 0.0

	# 3. Y-POSITION & MUD SUSPENSION
	is_physically_stable = max_tread_pen > -2.0

	if max_tread_pen > buffer:
		global_position.y -= (max_tread_pen - buffer)
		vertical_velocity = 0.0
	elif max_tread_pen > 0.0:
		var mud_thickness = max_tread_pen / buffer
		vertical_velocity = lerp(vertical_velocity, 0.0, 20.0 * mud_thickness * delta)

	# 4. ROTATION (Torsional Spring based on true highest contacts)
	var target_angle = sprite.rotation 

	if max_f_pen > -10.0 and max_b_pen > -10.0:
		var dx = abs(f_contact_pos.x - b_contact_pos.x)
		if dx > 1.0: target_angle = atan2(f_contact_pos.y - b_contact_pos.y, dx) * move_dir
	elif max_b_pen > -10.0:
		target_angle = 1.0 * move_dir
	elif max_f_pen > -10.0:
		target_angle = -1.0 * move_dir

	# PROPORTIONAL OVERRIDE (Fixes the Bounce!)
	# Instead of instantly snapping the angle by 1.0 (57 degrees), 
	# it gently and proportionally lifts the nose based on how deep it hit the wall!
	if max_bumper_pen > buffer:
		var bumper_push = (max_bumper_pen - buffer) * 0.05
		target_angle -= bumper_push * move_dir

	target_angle = clamp(target_angle, -1.0, 1.0)

	# 5. ANGULAR MOMENTUM (Vibration-Free Spring)
	var angle_diff = target_angle - sprite.rotation
	while angle_diff > PI: angle_diff -= PI * 2.0
	while angle_diff < -PI: angle_diff += PI * 2.0

	if is_physically_stable:
		# Softened spring force from 25.0 to 15.0 to heave smoothly and prevent jerking
		var spring_force = angle_diff * 15.0
		angular_velocity += spring_force * delta
		angular_velocity = lerp(angular_velocity, 0.0, 15.0 * delta)
	else:
		angular_velocity += (angle_diff * 5.0) * delta
		angular_velocity = lerp(angular_velocity, 0.0, 2.0 * delta)

	sprite.rotation = clamp(sprite.rotation, -1.2, 1.2)
	angular_velocity = clamp(angular_velocity, -3.0, 3.0)

	# 6. TRACTION
	current_traction = 1.0 if is_physically_stable else 0.2
