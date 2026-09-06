extends CanvasLayer

signal spawn_rifleman_requested
signal spawn_tank_requested
signal spawn_biplane_requested

var rifleman_on_cooldown: bool = false

func _ready() -> void:
	# Explicitly connect code to the buttons on startup
	$RiflemanButton.pressed.connect(_on_rifleman_button_pressed)
	$TankButton.pressed.connect(_on_tank_button_pressed)
	$PlaneButton.pressed.connect(_on_plane_button_pressed)

func _on_rifleman_button_pressed() -> void:
	if rifleman_on_cooldown:
		return
		
	if GameManager.spend_pigeons(75):
		spawn_rifleman_requested.emit()
		
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
		spawn_tank_requested.emit()
	else:
		print("Not enough pigeons! Need: 250")

func _on_plane_button_pressed() -> void:
	if GameManager.spend_pigeons(120):
		spawn_biplane_requested.emit()
	else:
		print("Not enough pigeons! Need: 120")
