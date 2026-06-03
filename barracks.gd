extends Node2D 

# Preload both blueprints so the factory can copy them
var soldier_scene = preload("res://soldier.tscn")
var biplane_scene = preload("res://biplane.tscn")

func _ready():
	# Wire up the Soldier Button
	var spawn_button = get_parent().get_node("CanvasLayer/Button")
	spawn_button.pressed.connect(_on_spawn_button_pressed)
	
	# Wire up the new Plane Button
	var plane_button = get_parent().get_node("CanvasLayer/PlaneButton")
	plane_button.pressed.connect(_on_plane_button_pressed)

# --- SOLDIER SPAWNING logic ---
func _on_spawn_button_pressed(): 
	if GameManager.spend_pigeons(75):
		spawn_soldier()
	else:
		print("Not enough pigeons for a soldier!")

func spawn_soldier():
	var new_soldier = soldier_scene.instantiate()
	get_parent().add_child(new_soldier)
	new_soldier.global_position = $Marker2D.global_position

# --- BIPLANE SPAWNING logic ---
func _on_plane_button_pressed():
	if GameManager.spend_pigeons(120): # Planes cost more!
		spawn_biplane()
	else:
		print("Not enough pigeons for air support!")

func spawn_biplane():
	var new_plane = biplane_scene.instantiate()
	
	# Add the plane to the battlefield scene tree FIRST
	get_parent().add_child(new_plane)
	
	# Assign the global position directly to match your new sky marker exactly!
	new_plane.global_position = $PlaneMarker.global_position
