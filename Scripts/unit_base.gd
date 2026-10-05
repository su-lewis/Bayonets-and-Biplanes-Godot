extends CharacterBody2D
class_name BaseUnit

enum State { ROLLOUT, DIAGONAL_PUSH, LANE_PUSH, ATTACK }

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

# --- VEHICLE PHYSICS VARIABLES ---
var ground_node: Polygon2D = null
var vertical_velocity: float = 0.0
var current_traction: float = 1.0 
var is_physically_stable: bool = true

# CHANGE THIS from 250.0 to 600.0 (or even 800.0 for massive weight)
var gravity: float = 600.0

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
		
	# Flip the Track Polygon for enemies so it matches the texture
	if is_enemy:
		var track_shape = _get_track_shape()
		if track_shape:
			var flipped_poly = PackedVector2Array()
			for pt in track_shape.polygon:
				flipped_poly.append(Vector2(-pt.x, pt.y))
			track_shape.polygon = flipped_poly
		
	if data.is_vehicle:
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
	var is_moving = (current_state != State.ATTACK)
	
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
	for weapon in weapon_cooldowns.keys():
		if weapon_cooldowns[weapon] > 0.0:
			weapon_cooldowns[weapon] -= delta

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
				
				var steepness_penalty = 1.0
				if pitch_angle < -0.6: 
					# Changed clamp min to 0.2 (20% power minimum) so they don't get fully stuck on steep walls
					steepness_penalty = clamp(1.0 - (abs(pitch_angle) - 0.6) * 2.0, 0.2, 1.0)
					
				var traction = 1.0 if is_physically_stable else 0.4
				var net_forward = (data.engine_power * traction * steepness_penalty) + slope_gravity
				var final_speed = clamp(net_forward, -data.move_speed * 0.5, data.move_speed)
				
				var forward_vector = Vector2(move_dir, 0).rotated(sprite.rotation)
				velocity = forward_vector * final_speed
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

	move_and_slide()
	
	if data.is_vehicle and is_instance_valid(ground_node):
		_apply_vehicle_physics(delta)

# --- WW1 RHOMBOID VEHICLE PHYSICS (STABLE HYBRID) ---
func _apply_vehicle_physics(delta: float) -> void:
	var track_shape = _get_track_shape()
	if not track_shape or not ground_node: return
	
	var load_bearing_pts = []
	var max_belly_pen = -9999.0
	
	var max_forward = 0.0
	var max_backward = 0.0

	# 1. FIND TANK DIMENSIONS
	for pt in track_shape.polygon:
		var true_x = pt.x * move_dir
		if true_x > max_forward: max_forward = true_x
		if true_x < max_backward: max_backward = true_x

	var belly_limit = max_forward * 0.60 

	# 2. EXACT RIGID BODY COLLISION SCANNING (Y-AXIS ONLY)
	for pt in track_shape.polygon:
		var true_x = pt.x * move_dir
		var global_pt = track_shape.to_global(pt)
		var local_x = ground_node.to_local(global_pt).x
		var exact_height = ground_node.get_exact_height(local_x)
		var dirt_y = ground_node.to_global(Vector2(local_x, exact_height)).y
		
		var penetration = global_pt.y - dirt_y 
		
		if penetration > 0.0:
			load_bearing_pts.append(global_pt)
			
		# ONLY the belly can lift the tank vertically! (Prevents nose levitation)
		if abs(true_x) <= belly_limit:
			if penetration > max_belly_pen: 
				max_belly_pen = penetration

	# 3. TERRAIN GRINDING (Chews steep walls into ramps)
	if load_bearing_pts.size() > 0 and load_bearing_pts.size() <= 4:
		var needs_visual_update = false
		var max_allowed_y = ground_node.base_ground_level + ground_node.lane_thickness - 10.0
		for p in load_bearing_pts:
			var center_x = int(ground_node.to_local(p).x)
			var radius = 20 
			var start_x = maxi(0, center_x - radius)
			var end_x = mini(ground_node.map_width - 1, center_x + radius)
			
			for x in range(start_x, end_x):
				var dist = abs(x - center_x)
				var slope = 1.0 - (float(dist) / radius)
				var depth = (data.weight_tons * 2.0 * delta * slope) / load_bearing_pts.size()
				ground_node.height_map[x] = min(ground_node.height_map[x] + depth, max_allowed_y)
			needs_visual_update = true
		if needs_visual_update:
			ground_node.mark_dirty()

	# 4. Y-POSITION: DRIVEN STRICTLY BY THE BELLY 
	# Buffer perfectly scales: 10px, 8.5px, 7px!
	var buffer = 10.0 * target_scale
	is_physically_stable = max_belly_pen > -buffer
	
	if not is_physically_stable:
		vertical_velocity += gravity * delta
		vertical_velocity = min(vertical_velocity, 500.0) 
		global_position.y += vertical_velocity * delta
	else:
		vertical_velocity = 0.0
		# Strict 10px limit. Pushes up smoothly if too deep.
		if max_belly_pen > buffer:
			global_position.y -= (max_belly_pen - buffer) * (15.0 * delta)
		elif max_belly_pen < 0.0:
			global_position.y -= max_belly_pen * (15.0 * delta)

	# 5. ROTATION: DECOUPLED TERRAIN SAMPLING (Anti-Spasm)
	# By reading the absolute terrain height, the tank's current rotation cannot cause a feedback loop!
	var f_x = global_position.x + (max_forward * 0.8 * target_scale * move_dir)
	var c_x = global_position.x
	var b_x = global_position.x + (max_backward * 0.8 * target_scale * move_dir)

	var yF = ground_node.to_global(Vector2(0, ground_node.get_exact_height(ground_node.to_local(Vector2(f_x, 0)).x))).y
	var yC = ground_node.to_global(Vector2(0, ground_node.get_exact_height(ground_node.to_local(Vector2(c_x, 0)).x))).y
	var yB = ground_node.to_global(Vector2(0, ground_node.get_exact_height(ground_node.to_local(Vector2(b_x, 0)).x))).y

	var dx = abs(f_x - c_x)
	var target_angle = 0.0

	if dx > 0.1:
		# Calculate the 3 possible slopes the tank could rest on
		var ang_BC = atan2(yC - yB, dx) * move_dir       # Resting on Back + Center
		var ang_CF = atan2(yF - yC, dx) * move_dir       # Resting on Center + Front
		var ang_BF = atan2(yF - yB, dx * 2.0) * move_dir # Bridging Back to Front

		var valid_angles = []
		# Only allow angles that don't clip the tank through the floor
		if (yB + 2.0 * (yC - yB)) <= yF + 5.0: valid_angles.append(ang_BC)
		if (yF - 2.0 * (yF - yC)) <= yB + 5.0: valid_angles.append(ang_CF)
		if ((yB + yF) / 2.0) <= yC + 5.0: valid_angles.append(ang_BF)

		# Of the valid angles, always pick the one that Pitches UP the most.
		# This causes the tank to realistically rear up on its back tracks when hitting a steep wall!
		if valid_angles.size() > 0:
			target_angle = valid_angles[0]
			for a in valid_angles:
				if a < target_angle: target_angle = a 

	target_angle = clamp(target_angle, -0.9, 0.9)

	# 6. HEAVY, FAST FALLING LERP
	# Increased from (5.0 / 2.0) to (10.0 / 6.0). 
	# The tank will now snap to the terrain and violently pitch nose-down much faster!
	var rot_weight = 10.0 if is_physically_stable else 6.0
	sprite.rotation = lerp_angle(sprite.rotation, target_angle, 1.0 - exp(-rot_weight * delta))
