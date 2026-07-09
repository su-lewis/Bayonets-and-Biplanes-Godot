extends Node2D

var soldier_scene: PackedScene = preload("res://Units/unit_rifleman.tscn")
var biplane_scene: PackedScene = preload("res://Units/unit_biplane.tscn")
var tank_scene: PackedScene = preload("res://Units/unit_mark1_tank.tscn")

# Drag these in from the Inspector!
@export var ground_lanes: Array[Node2D] = []
@export var canvas_layer: CanvasLayer
@export var infantry_marker: Marker2D
@export var tank_marker: Marker2D
@export var plane_marker: Marker2D

func _ready() -> void:
	if not canvas_layer:
		push_error("Canvas Layer not assigned in inspector!")
		return

	# Connect the buttons
	canvas_layer.get_node("RiflemanButton").pressed.connect(_try_buy.bind(75, spawn_unit.bind(soldier_scene, infantry_marker, false)))
	canvas_layer.get_node("PlaneButton").pressed.connect(_try_buy.bind(120, spawn_biplane))
	canvas_layer.get_node("TankButton").pressed.connect(_try_buy.bind(250, spawn_unit.bind(tank_scene, tank_marker, true)))

func _try_buy(cost: int, success_action: Callable) -> void:
	if GameManager.spend_pigeons(cost):
		success_action.call()
	else:
		print("Not enough pigeons! Need: ", cost)

func spawn_unit(scene_to_spawn: PackedScene, spawn_point: Node2D, send_to_back: bool = false) -> void:
	var new_unit = scene_to_spawn.instantiate()
	var chosen_lane = ground_lanes.pick_random()
	
	chosen_lane.add_child(new_unit)
	if send_to_back:
		chosen_lane.move_child(new_unit, 0)
		
	new_unit.z_index = 0
	if new_unit.has_node("Sprite2D"):
		new_unit.get_node("Sprite2D").z_index = 0
		
	new_unit.global_position = spawn_point.global_position
	new_unit.target_lane_y = chosen_lane.global_position.y
	new_unit.start_x = spawn_point.global_position.x 
	
	var lane_index = ground_lanes.find(chosen_lane)
	var scale_multipliers = [0.9, 0.95, 1.0]
	new_unit.target_scale = new_unit.base_scale * scale_multipliers[lane_index]

func spawn_biplane() -> void:
	var new_plane = biplane_scene.instantiate()
	
	var sky_tier: int = randi() % 2
	var base_sky_y: float = plane_marker.global_position.y
	var final_target_y: float = base_sky_y if sky_tier == 0 else (base_sky_y - 150.0)
	
	var visual_sorting_lane = ground_lanes.pick_random()
	visual_sorting_lane.add_child(new_plane)
	
	new_plane.global_position = Vector2(plane_marker.global_position.x, final_target_y)
