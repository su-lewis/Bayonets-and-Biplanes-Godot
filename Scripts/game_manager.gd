extends Node

signal pigeon_changed(new_count: int)

var pigeons: int = 0:
	set(value):
		pigeons = maxi(0, value) 
		pigeon_changed.emit(pigeons)

func _ready() -> void:
	var pigeon_timer = Timer.new()
	pigeon_timer.wait_time = 1.0
	pigeon_timer.timeout.connect(_on_pigeon_timer_timeout)
	
	add_child(pigeon_timer)
	pigeon_timer.start() 

	add_pigeons.call_deferred(8000)

func _on_pigeon_timer_timeout() -> void:
	add_pigeons(1)

func add_pigeons(amount: int) -> void:
	if amount <= 0: return 
	pigeons += amount

func spend_pigeons(amount: int) -> bool:
	if amount <= 0: return false
	if pigeons >= amount:
		pigeons -= amount
		return true
		
	print("Not enough pigeons!")
	return false
