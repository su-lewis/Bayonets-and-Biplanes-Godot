@tool
extends Polygon2D
class_name DestructibleGround

@export var map_width: int = 40000

@export var base_ground_level: float = 0.0:
	set(value):
		base_ground_level = value
		if Engine.is_editor_hint():
			_force_rebuild()

@export var lane_thickness: float = 250.0:
	set(value):
		lane_thickness = value
		if Engine.is_editor_hint():
			_force_rebuild()

var height_map: PackedFloat32Array = []
var visual_resolution: int = 20 
var custom_texture_scale: float = 0.25 

# CPU PERFORMANCE BATCHING FLAG
var _is_dirty: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		_force_rebuild()

func _physics_process(_delta: float) -> void:
	if _is_dirty:
		update_visual_polygon()
		_is_dirty = false

func mark_dirty() -> void:
	_is_dirty = true

func _force_rebuild() -> void:
	if height_map.size() != map_width:
		height_map.resize(map_width)
		
	height_map.fill(base_ground_level) 
	update_visual_polygon()

func update_visual_polygon() -> void:
	if height_map.is_empty(): return
	
	var points = PackedVector2Array()
	var uvs = PackedVector2Array()
	
	for x in range(0, map_width, visual_resolution):
		var current_y = height_map[x]
		var point = Vector2(x, current_y)
		points.append(point)
		uvs.append(point / custom_texture_scale)
		
	var final_x = map_width - 1
	var final_point = Vector2(final_x, height_map[final_x])
	points.append(final_point)
	uvs.append(final_point / custom_texture_scale)
		
	var lane_bottom_y = base_ground_level + lane_thickness 
	var bottom_right = Vector2(map_width, lane_bottom_y)
	var bottom_left = Vector2(0, lane_bottom_y)
	
	points.append(bottom_right)
	uvs.append(bottom_right / custom_texture_scale)
	
	points.append(bottom_left)
	uvs.append(bottom_left / custom_texture_scale)
	
	self.polygon = points
	self.uv = uvs

func blow_crater(hit_x_global: float, radius: int, max_depth: float) -> void:
	var center_x = int(to_local(Vector2(hit_x_global, 0)).x)
	var start_x = maxi(0, center_x - radius)
	var end_x = mini(map_width - 1, center_x + radius)
	
	var max_allowed_y = base_ground_level + lane_thickness - 10.0
	
	for x in range(start_x, end_x):
		var distance = abs(x - center_x)
		var slope_factor = 1.0 - (float(distance) / radius)
		var depth_to_add = (max_depth * slope_factor)
		
		height_map[x] = min(height_map[x] + depth_to_add, max_allowed_y)
			
	mark_dirty()

# SUB-PIXEL TERRAIN READING (Perfectly synced with Visuals)
func get_exact_height(local_x: float) -> float:
	if height_map.is_empty(): return base_ground_level
	
	var clamped_x = clamp(local_x, 0.0, float(map_width - 1))
	
	# We must calculate the slope using the EXACT same 20px steps the polygon draws with!
	var floor_x = int(clamped_x / visual_resolution) * visual_resolution
	var ceil_x = int(min(floor_x + visual_resolution, map_width - 1))
	
	if floor_x == ceil_x:
		return height_map[floor_x]
		
	# Interpolate along the visual straight line
	var weight = (clamped_x - float(floor_x)) / float(ceil_x - floor_x)
	return lerp(height_map[floor_x], height_map[ceil_x], weight)
