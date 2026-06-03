extends Node

# Global variable to track pigeons
var pigeons: int = 0:
	set(value):
		pigeons = value
		# Notify any UI connected to this signal
		pigeon_changed.emit(pigeons)

# Signal to bridge the gap between Logic and UI
signal pigeon_changed(new_count)

func _ready():
	# 1. Give yourself starting capital for testing
	add_pigeons(8000)
	
	# 2. Setup the Automated Economy Timer (Pure Code)
	var pigeon_timer = Timer.new()
	pigeon_timer.wait_time = 1.0 # Triggers every 1.0 seconds
	pigeon_timer.autostart = true
	
	# Connect the timer's signal to our income function
	pigeon_timer.timeout.connect(_on_pigeon_timer_timeout)
	
	# Add the timer to the GameManager so it actually runs
	add_child(pigeon_timer)

# This function is called every time the timer hits 1 second
func _on_pigeon_timer_timeout():
	add_pigeons(1)

func add_pigeons(amount: int):
	pigeons += amount

func spend_pigeons(amount: int) -> bool:
	if pigeons >= amount:
		pigeons -= amount
		return true
		
	print("Not enough pigeons!")
	return false
