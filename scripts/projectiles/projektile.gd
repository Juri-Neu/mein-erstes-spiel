extends Node2D

@export var speed := 300
var direction := Vector2.ZERO
@export var damage := 1
var target: Node2D

func _process(delta):
	print("Projectile at", global_position, "target:", target)
	if not target or not target.is_inside_tree():
		queue_free()
		return

	var dir = (target.global_position - global_position).normalized()
	global_position += dir * speed * delta

	if global_position.distance_to(target.global_position) < 10:
		if target.has_method("apply_damage"):
			target.apply_damage(damage)
		queue_free()
