extends Node2D

var soldier_scene: PackedScene = preload("res://Units/unit_rifleman.tscn")
var biplane_scene: PackedScene = preload("res://Units/unit_biplane.tscn")
var tank_scene: PackedScene = preload("res://Units/unit_mark1_tank.tscn")

# Inspector assignments
@export var ground_lanes: Array[Node2D] = []
@export var canvas_layer: CanvasLayer
@export var infantry_marker: Marker2D
@export var tank_marker: Marker2D
@export var plane_marker: Marker2D
@export var enemy_marker: Marker2D

var ordered_lanes: Array[Node2D] = []
var current_lane_index: int = 0

func _ready() -> void:
	if not canvas_layer:
		push_error("Canvas Layer not assigned in inspector!")
		return

	# Sort lanes by Y position (Bottom -> Middle -> Top)
	ordered_lanes = ground_lanes.duplicate()
	ordered_lanes.sort_custom(func(a, b): return a.global_position.y > b.global_position.y)

	# Connect buttons
	canvas_layer.get_node("RiflemanButton").pressed.connect(_try_buy.bind(75, spawn_unit.bind(soldier_scene, infantry_marker, false)))
	canvas_layer.get_node("PlaneButton").pressed.connect(_try_buy.bind(120, spawn_biplane))
	canvas_layer.get_node("TankButton").pressed.connect(_try_buy.bind(250, spawn_unit.bind(tank_scene, tank_marker, false)))

	# Test Enemy Spawner
	var enemy_timer = Timer.new()
	enemy_timer.wait_time = 5.0
	enemy_timer.autostart = true
	enemy_timer.timeout.connect(spawn_unit.bind(soldier_scene, enemy_marker, true))
	add_child(enemy_timer)

func _try_buy(cost: int, success_action: Callable) -> void:
	if GameManager.spend_pigeons(cost):
		success_action.call()
	else:
		print("Not enough pigeons! Need: ", cost)

func spawn_unit(scene_to_spawn: PackedScene, spawn_point: Node2D, is_enemy_team: bool = false) -> void:
	var new_unit = scene_to_spawn.instantiate()
	new_unit.is_enemy = is_enemy_team 
	
	var chosen_lane = ordered_lanes[current_lane_index]
	current_lane_index = (current_lane_index + 1) % ordered_lanes.size()
	
	chosen_lane.add_child(new_unit)
		
	new_unit.global_position = spawn_point.global_position
	new_unit.target_lane_y = chosen_lane.global_position.y
	new_unit.start_x = spawn_point.global_position.x 
	
	# --- RECALCULATED FOR 990 FLOOR LIMIT ---
	var min_scale: float = 0.75  # TopLane
	var max_scale: float = 1.00  # BottomLane
	var min_y: float = 570.0     # TopLane Y
	var max_y: float = 930.0     # BottomLane Y (Recalculated)

	var weight: float = clamp((chosen_lane.global_position.y - min_y) / (max_y - min_y), 0.0, 1.0)
	var perspective_scale: float = lerp(min_scale, max_scale, weight)

	new_unit.target_scale = new_unit.base_scale * perspective_scale

func spawn_biplane() -> void:
	var new_plane = biplane_scene.instantiate()
	
	var sky_tier: int = randi() % 2
	var base_sky_y: float = plane_marker.global_position.y
	var final_target_y: float = base_sky_y if sky_tier == 0 else (base_sky_y - 150.0)
	
	var visual_sorting_lane = ground_lanes.pick_random()
	visual_sorting_lane.add_child(new_plane)
	
	new_plane.global_position = Vector2(plane_marker.global_position.x, final_target_y)
