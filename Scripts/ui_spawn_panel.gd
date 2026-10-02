extends CanvasLayer

@export_category("Unit Roster")
@export var rifleman_data: UnitData
@export var tank_data: UnitData
@export var biplane_data: UnitData

@onready var label = $Label
@onready var btn_rifleman = $RiflemanButton
@onready var btn_tank = $TankButton
@onready var btn_plane = $PlaneButton

# Dictionary to track cooldowns securely outside of scene-tree timers
var cooldowns: Dictionary = {} 

func _ready() -> void:
	GameManager.war_bonds_changed.connect(_on_war_bonds_changed)
	_on_war_bonds_changed(GameManager.war_bonds)
	
	# Bind the specific .tres data to the shared function
	btn_rifleman.pressed.connect(_on_spawn_button_pressed.bind(rifleman_data, btn_rifleman))
	btn_tank.pressed.connect(_on_spawn_button_pressed.bind(tank_data, btn_tank))
	btn_plane.pressed.connect(_on_spawn_button_pressed.bind(biplane_data, btn_plane))

func _on_war_bonds_changed(new_count: int) -> void:
	if label:
		label.text = "War Bonds: " + str(new_count)

func _process(delta: float) -> void:
	# Process active cooldowns safely every frame
	for btn in cooldowns.keys():
		if cooldowns[btn] > 0.0:
			cooldowns[btn] -= delta
			if cooldowns[btn] <= 0.0:
				btn.disabled = false
				cooldowns.erase(btn)

func _on_spawn_button_pressed(data: UnitData, button: Button) -> void:
	if GameManager.spend_war_bonds(data.cost):
		SignalBus.spawn_unit_requested.emit(data, false)
		
		# Apply Cooldown
		var cd_time = 5.0 # You can add this variable to UnitData later if you want custom cooldowns!
		cooldowns[button] = cd_time
		button.disabled = true
	else:
		print("Not enough War Bonds! Need: ", data.cost)
