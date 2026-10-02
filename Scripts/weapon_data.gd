extends Resource
class_name WeaponData

@export var weapon_name: String = "Vickers MG"
@export var damage: float = 15.0
@export var penetration_mm: float = 8.0 # Standard rifle rounds
@export var attack_range: float = 180.0
@export var fire_rate: float = 0.2 # Shoots 5 times a second

@export_category("Ballistics")
@export var base_accuracy: float = 0.85 # 85% chance to hit while still
@export var moving_accuracy_penalty: float = 0.40 # Drops accuracy by 40% if walking
@export var vital_hit_chance: float = 0.10 # 10% chance to hit a vital organ for massive damage
