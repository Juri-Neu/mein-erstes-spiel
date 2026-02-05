extends Node2D

var enemies_in_range: Array = []
@export var projectile_scene: PackedScene

func _ready():
	$Range.body_entered.connect(_on_body_entered)
	$Range.body_exited.connect(_on_body_exited)
	$FireTimer.timeout.connect(_on_fire)
	$FireTimer.start()

func _on_body_entered(body):
	print("Groups of body:", body.get_groups())
	if body.is_in_group("enemies"):
		enemies_in_range.append(body)
		print("ADDED, count:", enemies_in_range.size())

func _on_body_exited(body):
	print("EXIT:", body)
	enemies_in_range.erase(body)
	print("REMOVED, count:", enemies_in_range.size())

func _on_fire():
	if enemies_in_range.is_empty():
		return
	var enemy = enemies_in_range[0]
	print("FIRING at", enemy)

	if projectile_scene == null:
		print("ERROR: projectile_scene is NULL")
		return

	# Projektil instanziieren
	var projectile = projectile_scene.instantiate()

	# Startposition (optional Marker2D)
	projectile.global_position = global_position  # oder $Muzzle.global_position

	# Ziel setzen
	projectile.target = enemy

	# Ins SceneTree hinzufügen
	get_tree().current_scene.add_child(projectile)

	print("Projectile instantiated:", projectile)
