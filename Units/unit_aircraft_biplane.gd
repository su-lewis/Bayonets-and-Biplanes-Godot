extends BaseUnit

@export var speed = 200.0

func _ready() -> void:
	super._ready() 
	
	# Air Unit specific stats
	max_hp = 50.0
	current_hp = max_hp
	armor_type = ArmorType.LIGHT
	damage_type = DamageType.BULLET
	
	# Planes ignore ground collisions completely
	collision_layer = 0
	collision_mask = 0

func _physics_process(delta: float) -> void:
	# Bypass move_and_slide, pure math movement
	global_position.x += (speed * move_dir) * delta
