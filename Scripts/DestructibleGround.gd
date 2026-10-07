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

# --- CHUNKING OPTIMIZATION ---
var chunk_size_px: int = 2000
var chunks: Array[Polygon2D] = []
var dirty_chunks: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		self.color.a = 1.0 # Keep visible in Editor
	else:
		self.color.a = 0.0 # Hide parent in Game (Chunks will take over)
		
	_force_rebuild()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint(): return # Don't run chunk updates in Editor
	
	if dirty_chunks.size() > 0:
		for chunk_idx in dirty_chunks.keys():
			_update_chunk(chunk_idx)
		dirty_chunks.clear()

func mark_region_dirty(start_x: int, end_x: int) -> void:
	if chunks.is_empty(): return
	var start_chunk = clampi(start_x / chunk_size_px, 0, chunks.size() - 1)
	var end_chunk = clampi(end_x / chunk_size_px, 0, chunks.size() - 1)
	
	for i in range(start_chunk, end_chunk + 1):
		dirty_chunks[i] = true

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
			
	mark_region_dirty(start_x, end_x)

func _force_rebuild() -> void:
	if height_map.size() != map_width:
		height_map.resize(map_width)
	height_map.fill(base_ground_level) 
	
	if Engine.is_editor_hint():
		# EDITOR: Draw one massive polygon so you can see it and the Orange Line matches
		_update_main_editor_polygon()
	else:
		# GAME: Empty the parent polygon and spawn the high-performance chunks
		self.polygon = PackedVector2Array() 
		
		for c in chunks:
			if is_instance_valid(c): c.queue_free()
		chunks.clear()
		dirty_chunks.clear()
		
		var num_chunks = ceili(float(map_width) / float(chunk_size_px))
		for i in range(num_chunks):
			var chunk_poly = Polygon2D.new()
			chunk_poly.texture = self.texture
			chunk_poly.texture_repeat = Polygon2D.TEXTURE_REPEAT_ENABLED
			chunk_poly.color = Color(1, 1, 1, 1) # Guaranteed to be visible!
			chunk_poly.z_index = self.z_index
			add_child(chunk_poly)
			chunks.append(chunk_poly)
			
			# Force it to build instantly so it doesn't blink on spawn
			_update_chunk(i) 

# --- EDITOR ONLY DRAWING ---
func _update_main_editor_polygon() -> void:
	if height_map.is_empty(): return
	var points = PackedVector2Array()
	var uvs = PackedVector2Array()
	
	for x in range(0, map_width, visual_resolution):
		var current_y = height_map[x]
		var point = Vector2(x, current_y)
		points.append(point)
		uvs.append(point / custom_texture_scale)
		
	var final_point = Vector2(map_width - 1, height_map[map_width - 1])
	points.append(final_point)
	uvs.append(final_point / custom_texture_scale)
		
	var lane_bottom_y = base_ground_level + lane_thickness 
	
	var bottom_right = Vector2(map_width - 1, lane_bottom_y)
	points.append(bottom_right)
	uvs.append(bottom_right / custom_texture_scale)
	
	var bottom_left = Vector2(0, lane_bottom_y)
	points.append(bottom_left)
	uvs.append(bottom_left / custom_texture_scale)
	
	self.polygon = points
	self.uv = uvs

# --- GAME CHUNK DRAWING ---
func _update_chunk(chunk_idx: int) -> void:
	if chunk_idx < 0 or chunk_idx >= chunks.size(): return
	
	var start_x = chunk_idx * chunk_size_px
	var end_x = mini(start_x + chunk_size_px, map_width - 1)
	
	var points = PackedVector2Array()
	var uvs = PackedVector2Array()
	
	for x in range(start_x, end_x, visual_resolution):
		var current_y = height_map[x]
		var point = Vector2(x, current_y)
		points.append(point)
		uvs.append(point / custom_texture_scale)
		
	var final_point = Vector2(end_x, height_map[end_x])
	points.append(final_point)
	uvs.append(final_point / custom_texture_scale)
		
	var lane_bottom_y = base_ground_level + lane_thickness 
	
	var bottom_right = Vector2(end_x, lane_bottom_y)
	points.append(bottom_right)
	uvs.append(bottom_right / custom_texture_scale)
	
	var bottom_left = Vector2(start_x, lane_bottom_y)
	points.append(bottom_left)
	uvs.append(bottom_left / custom_texture_scale)
	
	chunks[chunk_idx].polygon = points
	chunks[chunk_idx].uv = uvs

func get_exact_height(local_x: float) -> float:
	if height_map.is_empty(): return base_ground_level
	
	var clamped_x = clamp(local_x, 0.0, float(map_width - 1))
	var floor_x = int(clamped_x / visual_resolution) * visual_resolution
	var ceil_x = int(min(floor_x + visual_resolution, map_width - 1))
	
	if floor_x == ceil_x: return height_map[floor_x]
		
	var weight = (clamped_x - float(floor_x)) / float(ceil_x - floor_x)
	return lerp(height_map[floor_x], height_map[ceil_x], weight)
