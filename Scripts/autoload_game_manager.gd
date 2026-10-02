extends Node

signal war_bonds_changed(new_count: int)

var war_bonds: int = 0:
	set(value):
		war_bonds = maxi(0, value) 
		war_bonds_changed.emit(war_bonds)

func _ready() -> void:
	var bond_timer = Timer.new()
	bond_timer.wait_time = 1.0
	bond_timer.timeout.connect(func(): add_war_bonds(1))
	add_child(bond_timer)
	bond_timer.start() 

	add_war_bonds.call_deferred(8000)

func add_war_bonds(amount: int) -> void:
	if amount <= 0: return 
	war_bonds += amount

func spend_war_bonds(amount: int) -> bool:
	if amount <= 0: return false
	if war_bonds >= amount:
		war_bonds -= amount
		return true
	return false
