extends Area2D
class_name Trench

@export var max_garrison: int = 3
var current_occupants: Array = []
var owner_is_enemy: bool = false

func _ready() -> void:
	modulate.a = 0.0 # Starts invisible, Sapper fades it in!
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is BaseUnit and not body.data.is_vehicle:
		if body.is_enemy == owner_is_enemy:
			if current_occupants.size() < max_garrison:
				current_occupants.append(body)
				body.current_state = BaseUnit.State.GARRISONED

func _on_body_exited(body: Node2D) -> void:
	if body in current_occupants:
		current_occupants.erase(body)
