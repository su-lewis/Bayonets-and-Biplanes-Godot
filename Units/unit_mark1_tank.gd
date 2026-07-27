extends BaseUnit

func _ready() -> void:
	super._ready() 
	
	# Tank Balances
	max_hp = 400.0 # High health!
	current_hp = max_hp
	damage = 60.0 # Heavy shell!
	attack_cooldown = 3.0 # Takes 3 seconds to reload
	move_speed = 50.0 # Very slow
	walk_out_distance = 1100.0
	
	armor_type = ArmorType.HEAVY
	damage_type = DamageType.EXPLOSIVE
