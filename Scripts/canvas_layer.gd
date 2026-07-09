extends CanvasLayer

@onready var label = $Label

func _ready() -> void:
	GameManager.pigeon_changed.connect(_on_pigeon_changed)
	_on_pigeon_changed(GameManager.pigeons)

func _on_pigeon_changed(new_count: int) -> void:
	label.text = "Pigeons: " + str(new_count)
