extends Polygon2D

func _ready() -> void:
	var collider: CollisionPolygon2D = $"../GroundCollider"
	if collider:
		polygon = collider.polygon
		uv = polygon
	
	# Shrinks repeating 4K textures to fit 1080p
	texture_scale = Vector2(2.0, 2.0)
	texture_offset = Vector2.ZERO
