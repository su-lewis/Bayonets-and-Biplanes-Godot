extends Node
class_name VehiclePhysics

var unit: CharacterBody2D
var sprite: Node2D
var ground_node: Polygon2D

var current_speed: float = 0.0
var vertical_velocity: float = 0.0
var angular_velocity: float = 0.0
var current_mud_sink_ratio: float = 0.0
var gravity: float = 980.0

var cached_track_points: Array[Vector2] = []
var com_offset: Vector2 = Vector2.ZERO
const TRACK_SAMPLE_COUNT: int = 11

func setup(parent_unit: CharacterBody2D, parent_sprite: Node2D, ground: Polygon2D) -> void:
	unit = parent_unit
	sprite = parent_sprite
	ground_node = ground
	
	var track_node = _find_track_shape(unit)
	if track_node and track_node is CollisionPolygon2D:
		var poly = track_node.polygon
		
		# Flip for enemy team
		if unit.is_enemy:
			var flipped_poly = PackedVector2Array()
			for pt in poly:
				flipped_poly.append(Vector2(-pt.x, pt.y))
			track_node.polygon = flipped_poly
			poly = flipped_poly
			
		var local_poly: PackedVector2Array = []
		var min_x = 99999.0; var max_x = -99999.0
		var min_y = 99999.0; var max_y = -99999.0
		
		for pt in poly:
			var local_pt = unit.to_local(track_node.to_global(pt))
			local_poly.append(local_pt)
			if local_pt.x < min_x: min_x = local_pt.x
			if local_pt.x > max_x: max_x = local_pt.x
			if local_pt.y < min_y: min_y = local_pt.y
			if local_pt.y > max_y: max_y = local_pt.y

		# Center of Mass (horizontal center, low belly)
		com_offset = Vector2((min_x + max_x) * 0.5, lerpf(min_y, max_y, 0.55))

		# Grab all actual corners of the lower tracks (captures the climbing horns perfectly)
		cached_track_points.clear()
		for pt in local_poly:
			if pt.y > lerpf(min_y, max_y, 0.20):
				cached_track_points.append(pt)

		# Fill in the gaps so the beam doesn't sag between vertices
		for i in range(TRACK_SAMPLE_COUNT):
			var t = float(i) / float(TRACK_SAMPLE_COUNT - 1)
			var sample_x = lerpf(min_x, max_x, t)
			var lowest_y = -99999.0
			var found = false
			
			for j in range(local_poly.size()):
				var p1 = local_poly[j]
				var p2 = local_poly[(j + 1) % local_poly.size()]
				
				if (p1.x <= sample_x and p2.x >= sample_x) or (p2.x <= sample_x and p1.x >= sample_x):
					if p1.x != p2.x:
						var weight = (sample_x - p1.x) / (p2.x - p1.x)
						var y_on_seg = lerpf(p1.y, p2.y, weight)
						if y_on_seg > lowest_y:
							lowest_y = y_on_seg
							found = true
							
			if found:
				var candidate = Vector2(sample_x, lowest_y)
				var dup = false
				for existing in cached_track_points:
					if existing.distance_squared_to(candidate) < 9.0:
						dup = true; break
				if not dup:
					cached_track_points.append(candidate)

func _find_track_shape(node: Node) -> CollisionPolygon2D:
	if node.has_node("TrackShape") and node.get_node("TrackShape") is CollisionPolygon2D:
		return node.get_node("TrackShape") as CollisionPolygon2D
	if sprite and sprite.has_node("TrackShape") and sprite.get_node("TrackShape") is CollisionPolygon2D:
		return sprite.get_node("TrackShape") as CollisionPolygon2D
	for child in node.get_children():
		if child is CollisionPolygon2D:
			return child as CollisionPolygon2D
	return null

# --- THE GEOMETRIC RIGID-BEAM ENGINE ---
func apply_physics(delta: float, is_driving: bool) -> void:
	if not ground_node or not unit.data or cached_track_points.is_empty(): return

	var is_tank: bool = (unit.unit_type == unit.UnitType.TANK) if "unit_type" in unit else true
	var target_scale: float = unit.target_scale
	var move_dir: float = unit.move_dir
	var rot = sprite.rotation

	var gx_origin = ground_node.global_position.x
	var gy_origin = ground_node.global_position.y
	var com_world = unit.global_position + (com_offset * target_scale).rotated(rot)

	# 1. Zone Scanners
	# In Godot, smaller Y is HIGHER UP. We want the minimum needed Y.
	var req_f = 999999.0; var pt_f = Vector2.ZERO
	var req_m = 999999.0; var pt_m = Vector2.ZERO
	var req_b = 999999.0; var pt_b = Vector2.ZERO
	
	var max_pen = -99999.0
	var tread_depth = 1.5 * target_scale

	for pt in cached_track_points:
		var r_local = (pt - com_offset) * target_scale
		var r_world = r_local.rotated(rot)
		var p_world = com_world + r_world
		
		var dirt_y = gy_origin + ground_node.get_exact_height(p_world.x - gx_origin)
		var pen = p_world.y - dirt_y
		if pen > max_pen: max_pen = pen

		# The Chassis Y needed to place this specific point exactly on the dirt
		var needed_y = dirt_y - r_world.y + tread_depth
		var dist_com = r_local.x * move_dir

		# Assign to Front, Mid, or Rear zones (Finding the HIGHEST piece of ground in each zone)
		if dist_com > 4.0 * target_scale:
			if needed_y < req_f: req_f = needed_y; pt_f = Vector2(p_world.x, dirt_y)
		elif dist_com < -4.0 * target_scale:
			if needed_y < req_b: req_b = needed_y; pt_b = Vector2(p_world.x, dirt_y)
		else:
			if needed_y < req_m: req_m = needed_y; pt_m = Vector2(p_world.x, dirt_y)

		# Crush dirt if sinking heavily (prevents jitter by gently smoothing paths)
		if pen > 4.0 * target_scale and is_tank and ground_node.has_method("crush_dirt"):
			ground_node.crush_dirt(p_world.x, minf((pen - 4.0 * target_scale) * 0.5, 4.0) * delta)

	var is_grounded = max_pen > -5.0 * target_scale

	# 2. Geometric Resolution
	var target_pitch = rot
	var target_chassis_y = com_world.y

	if is_grounded:
		# Check if the Middle is higher than the Front and Rear (Hillcrest Teeter-Totter)
		var is_high_centered = (req_m < req_f - 2.0) and (req_m < req_b - 2.0)

		if is_high_centered:
			target_chassis_y = req_m
			if pt_f.y > pt_b.y:
				# Teetering forward over the crest
				var dx = abs(pt_f.x - pt_m.x)
				if dx > 1.0: target_pitch = atan2(pt_f.y - pt_m.y, dx) * move_dir
			else:
				# Teetering backward onto the crest
				var dx = abs(pt_m.x - pt_b.x)
				if dx > 1.0: target_pitch = atan2(pt_m.y - pt_b.y, dx) * move_dir
		else:
			# Normal rigid beam bridging (supports on front and rear)
			target_chassis_y = (req_f + req_b) * 0.5
			var dx = abs(pt_f.x - pt_b.x)
			if dx > 1.0: target_pitch = atan2(pt_f.y - pt_b.y, dx) * move_dir

		# Smooth Vertical Suspension
		var damp_y = 16.0 if is_tank else 12.0
		com_world.y = lerpf(com_world.y, target_chassis_y, 1.0 - exp(-damp_y * delta))
		vertical_velocity = 0.0

		# Inertial Rotation (Real mass momentum)
		var angle_diff = wrapf(target_pitch - rot, -PI, PI)
		var rot_spring = 8.0 if is_tank else 12.0
		var rot_damp = 6.0 if is_tank else 8.0

		angular_velocity += angle_diff * rot_spring * delta
		angular_velocity = lerpf(angular_velocity, 0.0, 1.0 - exp(-rot_damp * delta))
		
		# Heavy Turn Limit
		var max_w = 0.60 if is_tank else 1.20
		angular_velocity = clampf(angular_velocity, -max_w, max_w)
		rot += angular_velocity * delta

	else:
		# AIRBORNE BALLISTICS
		vertical_velocity += gravity * delta
		com_world.y += vertical_velocity * delta
		
		var natural_fall = 0.25 * move_dir
		var air_diff = wrapf(natural_fall - rot, -PI, PI)
		angular_velocity += air_diff * 3.0 * delta
		angular_velocity = lerpf(angular_velocity, 0.0, 1.0 - exp(-3.0 * delta))
		rot += angular_velocity * delta

	# 3. Engine Locomotion (Completely isolated from Y suspension)
	if is_driving:
		var slope_drag = sin(rot * move_dir) * 0.45
		var mud_drag = current_mud_sink_ratio * 0.25
		var speed_factor = clampf(1.0 - slope_drag - mud_drag, 0.4, 1.2)
		var target_speed = unit.data.move_speed * speed_factor
		
		current_speed = lerpf(current_speed, target_speed, 1.0 - exp(-10.0 * delta))
		var forward_step_x = cos(rot) * move_dir * current_speed * delta
		com_world.x += forward_step_x
		unit.velocity.x = cos(rot) * move_dir * current_speed

	# 4. Final Transform Updates
	var max_pitch = 0.65 if is_tank else 0.75
	rot = clampf(rot, -max_pitch, max_pitch)
	
	unit.global_position = com_world - (com_offset * target_scale).rotated(rot)
	sprite.rotation = rot

	# 5. UNBREAKABLE HARD FLOOR LIMIT
	# Physically tests the final transformed vertices. Impossible to sink past 2.5px.
	var final_deepest = 0.0
	for pt in cached_track_points:
		var p_world = unit.global_position + (pt * target_scale).rotated(rot)
		var dirt_y = gy_origin + ground_node.get_exact_height(p_world.x - gx_origin)
		var pen = p_world.y - dirt_y
		if pen > final_deepest: final_deepest = pen

	var limit = 2.5 * target_scale
	if final_deepest > limit:
		var excess = final_deepest - limit
		unit.global_position.y -= excess
		if vertical_velocity > 0.0: vertical_velocity = 0.0

	current_mud_sink_ratio = clampf(final_deepest / (8.0 * target_scale), 0.0, 1.0)
