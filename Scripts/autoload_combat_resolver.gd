extends Node

func calculate_damage(base_damage: float, pen_mm: float, armor_mm: float, is_vital_hit: bool) -> float:
	var final_damage = base_damage
	
	# Vital hits simulate heart/headshots
	if is_vital_hit:
		final_damage *= 3.0 
		
	# Armor vs Penetration Math
	if pen_mm >= armor_mm:
		return final_damage # Clean penetration
	elif pen_mm >= (armor_mm * 0.5):
		return final_damage * 0.3 # Partial spalling / bruising
	else:
		return 0.0 # Ricochet / completely absorbed by armor
