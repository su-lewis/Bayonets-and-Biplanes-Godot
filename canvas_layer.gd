extends CanvasLayer

# Assumes your label is a direct child named 'Label'
@onready var label = $Label

func _ready():
	# Connect to the global signal
	GameManager.pigeon_changed.connect(_on_pigeon_changed)
	
	# Set the initial count
	_on_pigeon_changed(GameManager.pigeons)

func _on_pigeon_changed(new_count):
	label.text = "Pigeons: " + str(new_count)
