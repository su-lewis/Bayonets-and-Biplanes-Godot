extends Node2D

@export_category("Unit Scenes")
@export var soldier_scene: PackedScene
@export var tank_scene: PackedScene
@export var biplane_scene: PackedScene

@export_category("Spawners and Lanes")
@export var ground_lanes: Array[Node2D] = []
@export var infantry_marker: Marker2D
@export var tank_marker: Marker2D
@export var plane_marker: Marker2D
@export var enemy_marker: Marker2D

var ordered_lanes: Array[Node2D] = []
var current_lane_index: int = 0

func _ready() -> void:
	# Ensure correct 2.5D visual rendering (Y-Sorting)
	y_sort_enabled = true 
	for lane in ground_lanes:
		lane.y_sort_enabled = true

	# Sort lanes by Y position (Bottom -> Middle -> Top)
	ordered_lanes = ground_lanes.duplicate()
	ordered_lanes.sort_custom(func(a, b): return a.global_position.y > b.global_position.y)

	# Connect to the global event bus
	SignalBus.spawn_rifleman_requested.connect(_on_ui_spawn_rifleman)
	SignalBus.spawn_tank_requested.connect(_on_ui_spawn_tank)
	SignalBus.spawn_biplane_requested.connect(spawn_biplane)

	# Test Enemy Spawner
	var enemy_timer = Timer.new()
	enemy_timer.wait_time = 6.0
	enemy_timer.autostart = true
	enemy_timer.timeout.connect(spawn_infantry_squad.bind(enemy_marker, true))
	add_child(enemy_timer)

# --- Receiver Functions ---
func _on_ui_spawn_rifleman() -> void:
	spawn_infantry_squad(infantry_marker, false)

func _on_ui_spawn_tank() -> void:
	spawn_unit(tank_scene, tank_marker, false)

# --- Physical Spawning Logic ---
func spawn_infantry_squad(spawn_point: Node2D, is_enemy_team: bool = false) -> void:
	if not soldier_scene: return
	
	var chosen_lane = ordered_lanes.pick_random()
	var squad_y_offset = randf_range(10.0, 35.0)
	var final_target_y = chosen_lane.global_position.y + squad_y_offset
	
	var min_scale: float = 0.70
	var max_scale: float = 1.00
	var min_y: float = 400.0
	var max_y: float = 990.0 
	var weight: float = clamp((final_target_y - min_y) / (max_y - min_y), 0.0, 1.0)
	var perspective_scale: float = lerp(min_scale, max_scale, weight)
	
	for i in range(5):
		var new_unit = soldier_scene.instantiate()
		new_unit.is_enemy = is_enemy_team
		chosen_lane.add_child(new_unit)
		
		var dir_modifier = -1 if is_enemy_team else 1
		var x_stagger = i * 45.0 * dir_modifier
		
		new_unit.global_position = spawn_point.global_position - Vector2(x_stagger, 0)
		new_unit.target_lane_y = final_target_y
		new_unit.start_x = spawn_point.global_position.x 
		new_unit.target_scale = new_unit.base_scale * perspective_scale

func spawn_unit(scene_to_spawn: PackedScene, spawn_point: Node2D, is_enemy_team: bool = false) -> void:
	if not scene_to_spawn: return
	
	var new_unit = scene_to_spawn.instantiate()
	new_unit.is_enemy = is_enemy_team 
	
	var chosen_lane = ordered_lanes[current_lane_index]
	current_lane_index = (current_lane_index + 1) % ordered_lanes.size()
	
	chosen_lane.add_child(new_unit)
	new_unit.global_position = spawn_point.global_position
	new_unit.target_lane_y = chosen_lane.global_position.y 
	new_unit.start_x = spawn_point.global_position.x 
	
	var min_scale: float = 0.70  
	var max_scale: float = 1.00  
	var min_y: float = 400.0     
	var max_y: float = 990.0     
	var weight: float = clamp((chosen_lane.global_position.y - min_y) / (max_y - min_y), 0.0, 1.0)
	var perspective_scale: float = lerp(min_scale, max_scale, weight)
	new_unit.target_scale = new_unit.base_scale * perspective_scale

func spawn_biplane() -> void:
	if not biplane_scene: return
	
	var new_plane = biplane_scene.instantiate()
	var sky_tier: int = randi() % 2
	var base_sky_y: float = plane_marker.global_position.y
	var final_target_y: float = base_sky_y if sky_tier == 0 else (base_sky_y - 150.0)
	
	var visual_sorting_lane = ground_lanes.pick_random()
	visual_sorting_lane.add_child(new_plane)
	new_plane.global_position = Vector2(plane_marker.global_position.x, final_target_y)
