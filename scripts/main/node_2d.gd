extends Node2D

@export var tower_scene: PackedScene
@export var path: Path2D
@export var min_distance_to_path := 30


func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		place_tower(get_global_mouse_position())


func place_tower(world_pos: Vector2):
	print("Trying to place tower at", world_pos)

	if tower_scene == null:
		print("ERROR: tower_scene is NULL")
		return

	if not path or not path.curve:
		print("ERROR: path missing")
		return

	# Abstand zum Pfad prüfen
	var local_pos = path.to_local(world_pos)
	var closest_point = path.curve.get_closest_point(local_pos)
	var distance = local_pos.distance_to(closest_point)

	if distance < min_distance_to_path:
		print("Too close to path")
		return

	var tower = tower_scene.instantiate()
	tower.global_position = world_pos
	add_child(tower)
