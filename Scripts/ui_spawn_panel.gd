extends CanvasLayer

var rifleman_on_cooldown: bool = false

@onready var label = $Label

func _ready() -> void:
	GameManager.pigeon_changed.connect(_on_pigeon_changed)
	_on_pigeon_changed(GameManager.pigeons)
	
	# Explicitly connect code to the buttons on startup
	$RiflemanButton.pressed.connect(_on_rifleman_button_pressed)
	$TankButton.pressed.connect(_on_tank_button_pressed)
	$PlaneButton.pressed.connect(_on_plane_button_pressed)

func _on_pigeon_changed(new_count: int) -> void:
	if label:
		label.text = "War Bonds: " + str(new_count)

func _on_rifleman_button_pressed() -> void:
	if rifleman_on_cooldown:
		return
		
	if GameManager.spend_pigeons(75):
		SignalBus.spawn_rifleman_requested.emit()
		
		rifleman_on_cooldown = true
		$RiflemanButton.disabled = true
		
		var cooldown_timer = get_tree().create_timer(5.0)
		cooldown_timer.timeout.connect(func():
			rifleman_on_cooldown = false
			$RiflemanButton.disabled = false
		)
	else:
		print("Not enough pigeons! Need: 75")

func _on_tank_button_pressed() -> void:
	if GameManager.spend_pigeons(250):
		SignalBus.spawn_tank_requested.emit()
	else:
		print("Not enough pigeons! Need: 250")

func _on_plane_button_pressed() -> void:
	if GameManager.spend_pigeons(120):
		SignalBus.spawn_biplane_requested.emit()
	else:
		print("Not enough pigeons! Need: 120")
