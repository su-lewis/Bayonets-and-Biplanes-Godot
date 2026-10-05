extends Resource
class_name UnitData

enum SpawnFacility { BARRACKS, FACTORY, HANGAR }

@export_category("Identity & Economy")
@export var unit_name: String = "Unit"
@export var scene: PackedScene
@export var cost: int = 100
@export var spawn_facility: SpawnFacility = SpawnFacility.BARRACKS
@export var squad_size: int = 1

@export_category("Combat & Survivability")
@export var max_hp: float = 100.0
@export var armor_thickness_mm: float = 2.0 
@export var weapons: Array[WeaponData] = []

@export_category("Movement")
@export var move_speed: float = 50.0
@export var walk_out_distance: float = 120.0
@export var is_flying: bool = false
@export var is_vehicle: bool = false
@export var weight_tons: float = 28.0 # Mark I was heavily armored
@export var engine_power: float = 400.0 # The raw pushing force (Torque/HP)
