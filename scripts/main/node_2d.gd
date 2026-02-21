extends Node2D

const Combatant = preload("res://scripts/combatant.gd")

const MAP_SIZE := Vector2(1280, 720)
const ALLY_ZONE_TOP := 380.0
const CASTLE_POSITION := Vector2(640, 660)
const PATH_LENGTH := 12

enum RunState { CHOOSE_EVENT, BATTLE, GAME_OVER }
enum EventType { BATTLE, REPAIR, UPGRADE, RECRUIT, BUILD_TOWER, RELIC, HERO }

var state: RunState = RunState.CHOOSE_EVENT
var act: int = 1
var node_index: int = 0

var resources := { "gold": 120, "wood": 80, "stone": 80, "crystal": 10 }
var relics: Array[String] = []

var castle: Combatant
var current_options: Array[Dictionary] = []
var pending_enemies: int = 0
var pending_unit_placements: int = 2
var pending_tower_placements: int = 1

var enemy_spawn_timer: Timer
var info_label: RichTextLabel

func _ready() -> void:
	randomize()
	_setup_ui()
	_setup_timers()
	_spawn_initial_forces()
	_generate_event_choices()

func _process(_delta: float) -> void:
	if state == RunState.BATTLE:
		_try_finish_battle()
	_check_game_over()
	_update_ui()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if state == RunState.CHOOSE_EVENT and event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_1:
			_choose_event(0)
		elif key_event.keycode == KEY_2:
			_choose_event(1)
		elif key_event.keycode == KEY_3:
			_choose_event(2)

	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		var pos := mouse_event.position
		if pos.y < ALLY_ZONE_TOP:
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and pending_unit_placements > 0:
			_spawn_squad(pos)
			pending_unit_placements -= 1
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and pending_tower_placements > 0:
			_spawn_tower(pos)
			pending_tower_placements -= 1

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	info_label = RichTextLabel.new()
	info_label.position = Vector2(12, 12)
	info_label.size = Vector2(700, 300)
	info_label.bbcode_enabled = false
	layer.add_child(info_label)

func _setup_timers() -> void:
	enemy_spawn_timer = Timer.new()
	enemy_spawn_timer.wait_time = 0.5
	enemy_spawn_timer.timeout.connect(_spawn_enemy)
	add_child(enemy_spawn_timer)

func _spawn_initial_forces() -> void:
	castle = _create_combatant(Combatant.Team.ALLY, Combatant.Role.CASTLE, CASTLE_POSITION)
	castle.max_hp = 350
	castle.hp = castle.max_hp
	castle.attack_damage = 0
	castle.attack_range = 0

	_spawn_squad(Vector2(590, 570))
	_spawn_squad(Vector2(690, 570))
	_spawn_hero(Vector2(640, 520))

func _generate_event_choices() -> void:
	state = RunState.CHOOSE_EVENT
	current_options.clear()

	for i in 3:
		var event_type: EventType = _random_event_type()
		current_options.append({
			"type": event_type,
			"label": _event_label(event_type)
		})

func _random_event_type() -> EventType:
	var list: Array[EventType] = [
		EventType.BATTLE,
		EventType.REPAIR,
		EventType.UPGRADE,
		EventType.RECRUIT,
		EventType.BUILD_TOWER,
		EventType.RELIC,
		EventType.HERO,
	]
	return list[randi() % list.size()]

func _event_label(event_type: EventType) -> String:
	match event_type:
		EventType.BATTLE: return "Kampf-Welle (+Ressourcen)"
		EventType.REPAIR: return "Burg reparieren"
		EventType.UPGRADE: return "Armee verbessern"
		EventType.RECRUIT: return "Söldner rekrutieren (+2 Platzierungen)"
		EventType.BUILD_TOWER: return "Turmbausatz (+1 Platzierung)"
		EventType.RELIC: return "Relikt finden"
		EventType.HERO: return "Helden-Ereignis"
	return "Unbekannt"

func _choose_event(option_index: int) -> void:
	if option_index < 0 or option_index >= current_options.size():
		return

	node_index += 1
	var event_type: EventType = current_options[option_index]["type"]
	match event_type:
		EventType.BATTLE:
			_start_battle()
		EventType.REPAIR:
			_apply_repair()
		EventType.UPGRADE:
			_apply_upgrade()
		EventType.RECRUIT:
			pending_unit_placements += 2
		EventType.BUILD_TOWER:
			pending_tower_placements += 1
		EventType.RELIC:
			_apply_relic()
		EventType.HERO:
			_spawn_hero(Vector2(randf_range(560, 720), randf_range(460, 590)))

	if state == RunState.CHOOSE_EVENT:
		_advance_or_regenerate_path()

func _advance_or_regenerate_path() -> void:
	if node_index >= PATH_LENGTH:
		act += 1
		node_index = 0
	_generate_event_choices()

func _start_battle() -> void:
	state = RunState.BATTLE
	pending_enemies = 7 + act * 3 + node_index * 2
	enemy_spawn_timer.start()

func _spawn_enemy() -> void:
	if pending_enemies <= 0:
		enemy_spawn_timer.stop()
		return

	pending_enemies -= 1
	var enemy := _create_combatant(
		Combatant.Team.ENEMY,
		Combatant.Role.SQUAD,
		Vector2(randf_range(40, MAP_SIZE.x - 40), randf_range(20, 90))
	)
	enemy.max_hp = 24 + act * 6 + node_index * 2
	enemy.hp = enemy.max_hp
	enemy.attack_damage = 4.0 + act * 0.9
	enemy.attack_cooldown = 1.1
	enemy.move_speed = 65 + act * 3
	enemy.attack_range = 34

func _try_finish_battle() -> void:
	if pending_enemies > 0:
		return
	if get_tree().get_nodes_in_group("enemies").size() > 0:
		return

	_apply_battle_reward()
	state = RunState.CHOOSE_EVENT
	_advance_or_regenerate_path()

func _apply_battle_reward() -> void:
	resources.gold += 30 + act * 10
	resources.wood += 18 + act * 5
	resources.stone += 18 + act * 5
	resources.crystal += 2 + int(act / 2)

func _apply_repair() -> void:
	if is_instance_valid(castle):
		castle.hp = min(castle.max_hp, castle.hp + 80)
	resources.stone = max(0, resources.stone - 15)

func _apply_upgrade() -> void:
	for node in get_tree().get_nodes_in_group("allies"):
		if not (node is Combatant):
			continue
		if node == castle:
			continue
		var ally := node as Combatant
		ally.max_hp += 4
		ally.hp += 4
		ally.attack_damage += 0.9
	resources.gold = max(0, resources.gold - 20)

func _apply_relic() -> void:
	var pool := [
		"Handelswappen: +15 Gold nach jedem Kampf",
		"Steinherz: +10 Stein bei jedem Event",
		"Kristallsplitter: +1 Kristall nach Kampf"
	]
	var relic: String = pool[randi() % pool.size()]
	relics.append(relic)

	if relic.begins_with("Steinherz"):
		resources.stone += 10

func _spawn_squad(pos: Vector2) -> void:
	var squad := _create_combatant(Combatant.Team.ALLY, Combatant.Role.SQUAD, pos)
	squad.max_hp = 42
	squad.hp = squad.max_hp
	squad.attack_damage = 5.2
	squad.attack_range = 36
	squad.attack_cooldown = 0.9
	squad.move_speed = 70

func _spawn_hero(pos: Vector2) -> void:
	var hero := _create_combatant(Combatant.Team.ALLY, Combatant.Role.HERO, pos)
	hero.max_hp = 90
	hero.hp = hero.max_hp
	hero.attack_damage = 12
	hero.attack_range = 44
	hero.attack_cooldown = 0.65
	hero.move_speed = 82

func _spawn_tower(pos: Vector2) -> void:
	var tower := _create_combatant(Combatant.Team.ALLY, Combatant.Role.TOWER, pos)
	tower.max_hp = 100
	tower.hp = tower.max_hp
	tower.attack_damage = 8.5
	tower.attack_range = 190
	tower.attack_cooldown = 0.85
	tower.can_move = false

func _create_combatant(team: int, role: int, pos: Vector2) -> Combatant:
	var combatant := Combatant.new()
	combatant.team = team
	combatant.role = role
	combatant.global_position = pos
	add_child(combatant)
	return combatant

func _check_game_over() -> void:
	if state == RunState.GAME_OVER:
		return
	if castle == null or not is_instance_valid(castle) or castle.hp <= 0.0:
		state = RunState.GAME_OVER
		enemy_spawn_timer.stop()

func _update_ui() -> void:
	if info_label == null:
		return

	var event_lines: Array[String] = []
	for i in current_options.size():
		event_lines.append("%d) %s" % [i + 1, current_options[i]["label"]])

	var state_text: String = ["EVENT", "BATTLE", "GAME OVER"][state]
	info_label.text = "Status: %s | Akt: %d | Pfadknoten: %d/%d\nGold %d | Holz %d | Stein %d | Kristall %d\nBurg HP: %.0f | Allies: %d | Enemies: %d\nPlatzierungen: Einheit(LK)=%d  Turm(RK)=%d\n\nEvent-Auswahl:\n%s\n\nRelikte: %s" % [
		state_text,
		act,
		node_index,
		PATH_LENGTH,
		resources.gold,
		resources.wood,
		resources.stone,
		resources.crystal,
		castle.hp if castle != null and is_instance_valid(castle) else 0.0,
		max(0, get_tree().get_nodes_in_group("allies").size() - 1),
		get_tree().get_nodes_in_group("enemies").size(),
		pending_unit_placements,
		pending_tower_placements,
		"\n".join(event_lines) if state == RunState.CHOOSE_EVENT else "(keine Auswahl während Kampf)",
		", ".join(relics) if relics.size() > 0 else "-"
	]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.07, 0.08, 0.1), true)
	draw_rect(Rect2(Vector2(0, ALLY_ZONE_TOP), Vector2(MAP_SIZE.x, MAP_SIZE.y - ALLY_ZONE_TOP)), Color(0.1, 0.14, 0.1), true)
	draw_line(Vector2(0, ALLY_ZONE_TOP), Vector2(MAP_SIZE.x, ALLY_ZONE_TOP), Color(0.45, 0.65, 0.45), 2.0)
