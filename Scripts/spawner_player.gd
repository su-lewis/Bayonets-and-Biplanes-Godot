extends Node2D

@export_category("Lanes & Markers")
@export var ground_lanes: Array[Node2D] = []
@export var low_sky_lane: Node2D 
@export var infantry_marker: Marker2D
@export var tank_marker: Marker2D
@export var plane_marker: Marker2D

var ordered_lanes: Array[Node2D] = []
var current_lane_index: int = 0
var lane_sub_indexes: Dictionary = {} # Tracks whether a lane is using the +30, +60, or +90 slot next

func _ready() -> void:
	y_sort_enabled = true 
	for lane in ground_lanes:
		lane.y_sort_enabled = true

	ordered_lanes = ground_lanes.duplicate()
	ordered_lanes.sort_custom(func(a, b): return a.global_position.y > b.global_position.y)

	# Initialize sub-lane trackers for each ground lane (0 = 30px, 1 = 60px, 2 = 90px)
	for i in range(ordered_lanes.size()):
		lane_sub_indexes[i] = 0

	SignalBus.spawn_unit_requested.connect(_on_spawn_unit_requested)

func _on_spawn_unit_requested(unit_data: UnitData, is_enemy_team: bool) -> void:
	if not unit_data or not unit_data.scene: return
	
	var spawn_point: Node2D = infantry_marker
	match unit_data.spawn_facility:
		UnitData.SpawnFacility.FACTORY: spawn_point = tank_marker
		UnitData.SpawnFacility.HANGAR: spawn_point = plane_marker

	# 1. Handle Air Units
	if unit_data.is_flying:
		var new_plane = unit_data.scene.instantiate()
		new_plane.data = unit_data
		new_plane.is_enemy = is_enemy_team
		
		if low_sky_lane:
			low_sky_lane.add_child(new_plane)
			new_plane.global_position = Vector2(spawn_point.global_position.x, low_sky_lane.global_position.y)
		else:
			push_error("Low Sky Lane not assigned in Inspector!")
		return

	# 2. Handle Ground Units & Squads
	var min_y: float = 400.0
	var max_y: float = 990.0 
	
	# Pre-calculate the base lane so infantry squads stick together
	var base_lane_idx = current_lane_index
	current_lane_index = (current_lane_index + 1) % ordered_lanes.size()
	
	# Calculate infantry sub-lane (+30, +60, +90)
	var sub_offsets = [30.0, 60.0, 90.0]
	var infantry_y_offset = 0.0
	
	if not unit_data.is_vehicle:
		var sub_idx = lane_sub_indexes.get(base_lane_idx, 0)
		infantry_y_offset = sub_offsets[sub_idx]
		# Cycle to the next sub-lane down for the next squad that spawns here
		lane_sub_indexes[base_lane_idx] = (sub_idx + 1) % 3 
		
	for i in range(unit_data.squad_size):
		var new_unit = unit_data.scene.instantiate()
		new_unit.data = unit_data
		new_unit.is_enemy = is_enemy_team
		
		var lane_idx = base_lane_idx
		var final_y_offset = infantry_y_offset
		var x_stagger = i * 45.0 * (-1 if is_enemy_team else 1)
		
		if unit_data.is_vehicle:
			final_y_offset = 0.0 # Vehicles always hug the true top line of the lane
			
			# If multiple vehicles spawn, separate them into different main lanes entirely
			if unit_data.squad_size > 1:
				lane_idx = (base_lane_idx + i) % ordered_lanes.size()
				x_stagger = 0.0 # No need to stagger X if they are in different lanes
				
		var chosen_lane = ordered_lanes[lane_idx]
		new_unit.lane_id = lane_idx 
		chosen_lane.add_child(new_unit)
		
		var final_target_y = chosen_lane.global_position.y + final_y_offset
		var weight = clamp((final_target_y - min_y) / (max_y - min_y), 0.0, 1.0)
		
		new_unit.global_position = spawn_point.global_position - Vector2(x_stagger, 0)
		new_unit.target_lane_y = final_target_y
		new_unit.start_x = spawn_point.global_position.x 
		new_unit.target_scale = new_unit.base_scale * lerp(0.70, 1.00, weight)
