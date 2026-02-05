extends Node2D

@export var speed := 100
@export var path_follow: PathFollow2D

func _process(delta):
	if path_follow == null:
		return

	path_follow.progress += speed * delta
	global_position = path_follow.global_position

@export var hp := 5

func apply_damage(amount):
	hp -= amount
	print("Enemy HP:", hp)
	if hp <= 0:
		queue_free()
