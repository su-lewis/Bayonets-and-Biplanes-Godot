extends Node

@warning_ignore("unused_signal")
signal spawn_unit_requested(data: UnitData, is_enemy: bool)
signal build_trench_requested(click_pos: Vector2, lane: Node2D)
signal artillery_requested(click_pos: Vector2, lane: Node2D)
