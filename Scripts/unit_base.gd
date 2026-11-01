extends CharacterBody2D
class_name BaseUnit

enum State { ROLLOUT, DIAGONAL_PUSH, LANE_PUSH, ATTACK, MOVE_TO_BUILD, DIGGING, GARRISONED }
enum UnitType { TANK = 10, ARMORED_CAR = 50, INFANTRY = 100 }

@export_category("Unit Data & Configuration")
@export var data: UnitData
@export var unit_type: UnitType = UnitType.TANK
@export var is_infantry: bool = false
@export_range(0, 2) var infantry_sub_lane: int = 0 

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

var perspective_min_y: float = 400.0
var perspective_max_y: float = 990.0
@export var diagonal_angle_degrees: float = 30.0

static var global_spawn_counter: int = 0
var assigned_tie_breaker: int = 0

var is_sapper: bool = false
var build_target_x: float = 0.0
var built_trench: Node2D = null

var ground_node: Polygon2D = null
var search_timer: float = 0.0

@onready var sprite = $Sprite2D
var motor: VehiclePhysics

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	current_hp = data.max_hp if data else 100.0
	start_x = global_position.x
	start_y_for_scale = global_position.y

	global_spawn_counter = (global_spawn_counter + 1) % 40
	assigned_tie_breaker = global_spawn_counter
	z_index = (200 + (infantry_sub_lane * 50) if is_infantry else int(unit_type)) + assigned_tie_breaker

	if sprite: 
		base_scale = abs(sprite.scale.x)
		update_perspective_scale()
		
	move_dir = -1.0 if is_enemy else 1.0
	add_to_group("enemy_units" if is_enemy else "player_units")

	if data:
		for weapon in data.weapons:
			weapon_cooldowns[weapon] = 0.0
		
	if is_sapper:
		current_state = State.MOVE_TO_BUILD
		
	if data and (data.is_vehicle or is_sapper):
		var parent_lane = get_parent()
		if parent_lane and parent_lane.has_node("DestructibleGround"):
			ground_node = parent_lane.get_node("DestructibleGround")
			
	# Connect Physics Component if this is a vehicle
	motor = get_node_or_null("VehiclePhysics")
	if motor:
		motor.setup(self, sprite, ground_node)

func update_perspective_scale() -> void:
	if not sprite: return
	var weight = clamp((global_position.y - perspective_min_y) / (perspective_max_y - perspective_min_y), 0.0, 1.0)
	target_scale = base_scale * lerp(0.70, 1.00, weight)
	_set_sprite_scale(target_scale)

func _set_sprite_scale(s: float) -> void:
	if not sprite: return
	sprite.scale = Vector2(s, s)
	if sprite is Sprite2D or sprite is AnimatedSprite2D:
		sprite.flip_h = is_enemy

func take_damage(amount: float, pen_mm: float, is_vital: bool) -> void:
	var armor = data.armor_thickness_mm if data else 0.0
	var actual_damage = CombatResolver.calculate_damage(amount, pen_mm, armor, is_vital)
	
	if current_state == State.GARRISONED: actual_damage *= 0.5
		
	if actual_damage > 0:
		current_hp -= actual_damage
		if sprite:
			sprite.modulate = Color.RED
			get_tree().create_timer(0.1).timeout.connect(func(): if is_instance_valid(sprite): sprite.modulate = Color.WHITE)
	if current_hp <= 0:
		queue_free()

func _find_target() -> void:
	if not data: return
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
	if not data or not is_instance_valid(current_target): return
	var dist = abs(current_target.global_position.x - global_position.x)
	var is_moving = (current_state != State.ATTACK and current_state != State.GARRISONED)
	
	for weapon in data.weapons:
		if weapon_cooldowns[weapon] <= 0.0 and dist <= weapon.attack_range:
			weapon_cooldowns[weapon] = weapon.fire_rate
			var hit_chance = weapon.base_accuracy
			if is_moving: hit_chance -= weapon.moving_accuracy_penalty
			var dice_roll = randf()
			var is_hit = dice_roll <= hit_chance
			
			_spawn_tracer(current_target, is_hit)
			if is_hit:
				current_target.take_damage(weapon.damage, weapon.penetration_mm, dice_roll <= weapon.vital_hit_chance)

func _spawn_tracer(target: BaseUnit, is_hit: bool) -> void:
	var tracer = Line2D.new()
	tracer.width = 1.0
	tracer.default_color = Color(1.0, 0.9, 0.5, 0.8)
	var start_pos = global_position + Vector2(10 * move_dir, -10)
	var end_pos = target.global_position + Vector2(0, -10)
	
	if not is_hit:
		end_pos += Vector2(randf_range(20.0, 50.0) * move_dir, randf_range(-40.0, 40.0))
		
	tracer.add_point(start_pos)
	tracer.add_point(end_pos)
	get_parent().add_child(tracer)
	var tween = create_tween()
	tween.tween_property(tracer, "modulate:a", 0.0, 0.1)
	tween.tween_callback(tracer.queue_free)

func _physics_process(delta: float) -> void:
	if not data: return
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
			if current_state != State.GARRISONED: current_state = State.ATTACK 

	if current_state == State.ATTACK:
		if not is_instance_valid(current_target):
			current_state = State.LANE_PUSH
		else:
			var max_range: float = 0.0
			for w in data.weapons:
				if w.attack_range > max_range: max_range = w.attack_range
			var dist = (current_target.global_position.x - global_position.x) * move_dir
			if dist < 0.0 or dist > max_range:
				current_target = null
				current_state = State.LANE_PUSH
			else:
				_fire_weapons()

	match current_state:
		State.ROLLOUT:
			velocity = Vector2(data.move_speed * move_dir, 0)
			update_perspective_scale()
			
			var rollout_complete: bool = false
			if not is_enemy and global_position.x >= start_x + data.walk_out_distance: rollout_complete = true
			elif is_enemy and global_position.x <= start_x - data.walk_out_distance: rollout_complete = true

			if rollout_complete:
				start_y_for_scale = global_position.y
				if is_sapper: current_state = State.MOVE_TO_BUILD
				elif abs(target_lane_y - global_position.y) <= 12.0:
					global_position.y = target_lane_y
					update_perspective_scale()
					current_state = State.LANE_PUSH
				else: current_state = State.DIAGONAL_PUSH
				
		State.DIAGONAL_PUSH:
			var y_diff = target_lane_y - global_position.y
			if abs(y_diff) <= 3.0:
				global_position.y = target_lane_y
				update_perspective_scale()
				current_state = State.LANE_PUSH
			else:
				var rad = deg_to_rad(diagonal_angle_degrees)
				velocity = Vector2(cos(rad) * move_dir, sin(rad) * sign(y_diff)).normalized() * data.move_speed
				update_perspective_scale()
				
		State.LANE_PUSH:
			if motor:
				update_perspective_scale()
			else:
				velocity = Vector2(data.move_speed * move_dir, 0)
				update_perspective_scale()
				if sprite is AnimatedSprite2D and sprite.animation != "walk": sprite.play("walk")
			if is_instance_valid(current_target): _fire_weapons()
				
		State.ATTACK:
			velocity = Vector2.ZERO 
			if sprite is AnimatedSprite2D and sprite.animation != "aim": sprite.play("aim")

		State.MOVE_TO_BUILD:
			velocity = Vector2(data.move_speed * move_dir, 0)
			update_perspective_scale()
			if sprite is AnimatedSprite2D and sprite.animation != "walk": sprite.play("walk")
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
				var flat_w = int(30 * target_scale); var slope_w = int(20 * target_scale)
				var depth = 40.0 * target_scale; var dig_spd = 20.0 * target_scale * delta
				var is_done = ground_node.carve_trench_step(global_position.x, flat_w, slope_w, depth, dig_spd)
				if built_trench: built_trench.modulate.a = min(built_trench.modulate.a + (1.5 * delta), 1.0)
				if is_done: current_state = State.GARRISONED
					
		State.GARRISONED:
			velocity = Vector2.ZERO
			if is_instance_valid(current_target): 
				_fire_weapons()
				if sprite is AnimatedSprite2D and sprite.animation != "aim": sprite.play("aim")
			else:
				if sprite is AnimatedSprite2D and sprite.animation != "idle": sprite.play("idle")

	# Delegate motion to physics component if it exists
	if motor and current_state in [State.LANE_PUSH, State.ATTACK]:
		motor.apply_physics(delta, current_state == State.LANE_PUSH)
	else:
		move_and_slide()
