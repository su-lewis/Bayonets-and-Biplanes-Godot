extends BaseUnit

func _ready() -> void:
	super._ready() 
	
	# Rifleman Balances
	max_hp = 80.0
	current_hp = max_hp
	damage = 15.0
	attack_cooldown = 1.0 # Shoots fast
	move_speed = 50.0 # Walks fast
	walk_out_distance = 400.0
	
	armor_type = ArmorType.LIGHT
	damage_type = DamageType.BULLET
