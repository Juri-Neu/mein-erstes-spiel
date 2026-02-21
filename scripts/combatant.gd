extends Node2D
class_name Combatant

enum Team { ALLY, ENEMY }
enum Role { CASTLE, TOWER, SQUAD, HERO }

@export var team: Team = Team.ALLY
@export var role: Role = Role.SQUAD
@export var max_hp: float = 30.0
@export var attack_damage: float = 4.0
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.0
@export var move_speed: float = 70.0
@export var can_move: bool = true

var hp: float = 0.0
var _cooldown_left: float = 0.0
var _target: Combatant

func _ready() -> void:
	hp = max_hp
	add_to_group("combatants")
	add_to_group("allies" if team == Team.ALLY else "enemies")
	match role:
		Role.CASTLE:
			add_to_group("castle")
			can_move = false
		Role.TOWER:
			add_to_group("tower")
			can_move = false
		Role.SQUAD:
			add_to_group("squad")
		Role.HERO:
			add_to_group("hero")

func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta

	if not _is_valid_target(_target):
		_target = _find_closest_enemy()

	if _target == null:
		queue_redraw()
		return

	var dist := global_position.distance_to(_target.global_position)
	if dist <= attack_range:
		if _cooldown_left <= 0.0:
			_target.apply_damage(attack_damage)
			_cooldown_left = attack_cooldown
	elif can_move:
		var direction := ( _target.global_position - global_position ).normalized()
		global_position += direction * move_speed * delta

	queue_redraw()

func apply_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		queue_free()

func _is_valid_target(candidate: Combatant) -> bool:
	return candidate != null and is_instance_valid(candidate) and candidate.is_inside_tree()

func _find_closest_enemy() -> Combatant:
	var group_names := ["enemies"] if team == Team.ALLY else ["allies", "castle"]
	var best: Combatant
	var best_distance := INF

	for group_name in group_names:
		for node in get_tree().get_nodes_in_group(group_name):
			if node == self or not (node is Combatant):
				continue
			var combatant := node as Combatant
			var dist := global_position.distance_to(combatant.global_position)
			if dist < best_distance:
				best_distance = dist
				best = combatant

	return best

func _draw() -> void:
	var color := Color.ROYAL_BLUE if team == Team.ALLY else Color.INDIAN_RED
	var radius := 12.0

	match role:
		Role.CASTLE:
			color = Color.DARK_GOLDENROD
			radius = 26.0
		Role.TOWER:
			color = Color.SEA_GREEN
			radius = 15.0
		Role.HERO:
			color = Color.MEDIUM_PURPLE
			radius = 14.0

	draw_circle(Vector2.ZERO, radius, color)
	var hp_ratio := clampf(hp / max(max_hp, 1.0), 0.0, 1.0)
	draw_rect(Rect2(Vector2(-18, -26), Vector2(36, 4)), Color(0.12, 0.12, 0.12), true)
	draw_rect(Rect2(Vector2(-18, -26), Vector2(36 * hp_ratio, 4)), Color(0.4, 1.0, 0.4), true)
