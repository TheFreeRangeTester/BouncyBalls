extends Control

## Panel de debug para probar power-ups y enemigos en escenarios controlados.
## Se accede desde la pantalla inicial (Debug mode). Solo spawnea bola, power-up elegido y un enemigo.

enum PowerUpType { NINGUNO, BOOST, SHIELD, POISON }

@export var bola_spawn_pos := Vector2(307, 55)
@export var powerup_spawn_pos := Vector2(400, 250)
@export var enemy_spawn_pos := Vector2(400, 450)

@export var powerup_scene: PackedScene
@export var shield_powerup_scene: PackedScene
@export var poison_powerup_scene: PackedScene
@export var enemy_scene: PackedScene

var _powerup_option: OptionButton
var _enemy_hp_spin: SpinBox
var _spawn_btn: Button

func _ready():
	visible = false
	_build_ui()
	# Cargar escenas si no están asignadas
	if not powerup_scene:
		powerup_scene = load("res://Scenes/PowerUp.tscn") as PackedScene
	if not shield_powerup_scene:
		shield_powerup_scene = load("res://Scenes/ShieldPowerUp.tscn") as PackedScene
	if not poison_powerup_scene:
		poison_powerup_scene = load("res://Scenes/PoisonPowerUp.tscn") as PackedScene
	if not enemy_scene:
		enemy_scene = load("res://Scenes/Enemy.tscn") as PackedScene

func _build_ui():
	# Panel de fondo
	var panel = Panel.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -280
	panel.offset_right = 20
	panel.offset_top = 20
	panel.offset_bottom = 260
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# Título
	var title = Label.new()
	title.text = "DEBUG - Power-ups"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	# Power-up
	var pw_label = Label.new()
	pw_label.text = "Power-up:"
	vbox.add_child(pw_label)
	
	_powerup_option = OptionButton.new()
	_powerup_option.add_item("Ninguno", PowerUpType.NINGUNO)
	_powerup_option.add_item("Boost", PowerUpType.BOOST)
	_powerup_option.add_item("Shield", PowerUpType.SHIELD)
	_powerup_option.add_item("Poison", PowerUpType.POISON)
	_powerup_option.selected = 0
	vbox.add_child(_powerup_option)
	
	# Enemy HP
	var hp_label = Label.new()
	hp_label.text = "Enemigo HP:"
	vbox.add_child(hp_label)
	
	_enemy_hp_spin = SpinBox.new()
	_enemy_hp_spin.min_value = 1
	_enemy_hp_spin.max_value = 8
	_enemy_hp_spin.value = 5
	_enemy_hp_spin.step = 1
	vbox.add_child(_enemy_hp_spin)
	
	# Botón Spawn
	_spawn_btn = Button.new()
	_spawn_btn.text = "Spawn escenario"
	_spawn_btn.pressed.connect(_on_spawn_pressed)
	vbox.add_child(_spawn_btn)
	
	# Botón Volver
	var back_btn = Button.new()
	back_btn.text = "Volver"
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

func _on_spawn_pressed():
	_spawn_debug_scenario()

func _on_back_pressed():
	visible = false
	var root = get_tree().root.get_child(0)
	var start_screen = root.get_node_or_null("CanvasLayer/UI/StartScreen")
	var game_manager = root.get_node_or_null("GameManager")
	if start_screen:
		start_screen.visible = true
	if game_manager:
		if "debug_mode" in game_manager:
			game_manager.debug_mode = false
		if "state" in game_manager:
			game_manager.state = 1  # WAITING_TO_START
	# Pausar bola y limpiar
	var bola = root.get_node_or_null("Bola")
	if bola and bola.has_method("pause_ball"):
		bola.pause_ball()
		bola.global_position = Vector2(307, 55)
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("powerups"):
		if is_instance_valid(node):
			node.queue_free()

func _spawn_debug_scenario():
	var root = get_tree().root.get_child(0)
	var bola = root.get_node_or_null("Bola")
	var enemy_spawner = root.get_node_or_null("EnemySpawner")
	var powerup_spawner = root.get_node_or_null("PowerUpSpawner")
	var game_manager = root.get_node_or_null("GameManager")
	
	if not bola:
		push_error("DebugPanel: No se encontró Bola")
		return
	
	# Pausar todos los spawners normales (solo bola, power-up y enemigo en debug)
	if enemy_spawner and enemy_spawner.has_method("pause_spawning"):
		enemy_spawner.pause_spawning()
	if powerup_spawner and powerup_spawner.has_method("pause_spawning"):
		powerup_spawner.pause_spawning()
	var laser_spawner = root.get_node_or_null("LaserSpawner")
	var misil_spawner = root.get_node_or_null("MisilSpawner")
	if laser_spawner and laser_spawner.has_method("pause_spawning"):
		laser_spawner.pause_spawning()
	if misil_spawner and misil_spawner.has_method("pause_spawning"):
		misil_spawner.pause_spawning()
	
	# Limpiar enemigos y power-ups existentes
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("powerups"):
		if is_instance_valid(node):
			node.queue_free()
	
	# Posicionar y reiniciar bola
	bola.global_position = bola_spawn_pos
	if bola.has_method("resume_ball"):
		bola.resume_ball()
	
	# Spawnear power-up elegido (o activarlo directamente en el caso de veneno para debug)
	var pw_type = _powerup_option.get_selected_id()
	if pw_type == PowerUpType.BOOST and powerup_scene:
		_spawn_powerup(powerup_scene, powerup_spawn_pos, bola, powerup_spawner)
	elif pw_type == PowerUpType.SHIELD and shield_powerup_scene:
		_spawn_powerup(shield_powerup_scene, powerup_spawn_pos, bola, powerup_spawner)
	elif pw_type == PowerUpType.POISON:
		# Veneno: activar directamente en la bola para que esté listo al chocar con el enemigo
		if bola.has_method("_on_poison_collected"):
			bola._on_poison_collected()
	
	# Spawnear enemigo
	if enemy_scene:
		_spawn_enemy(int(_enemy_hp_spin.value), enemy_spawn_pos, root, game_manager)
	
	# Ocultar StartLabel si existe
	var start_label = root.get_node_or_null("CanvasLayer/UI/StartLabel")
	if start_label:
		start_label.visible = false
	
	# Forzar estado playing en GameManager (PLAYING = 0)
	if game_manager and "state" in game_manager:
		game_manager.state = 0

func _spawn_powerup(scene: PackedScene, pos: Vector2, bola: Node, powerup_spawner: Node):
	var powerup = scene.instantiate()
	powerup.global_position = pos
	powerup.add_to_group("powerups")
	
	# Conectar señales a la bola
	if powerup.has_signal("powerup_collected"):
		powerup.powerup_collected.connect(bola._on_powerup_collected)
	elif powerup.has_signal("shield_collected"):
		powerup.shield_collected.connect(bola._on_shield_collected)
	elif powerup.has_signal("poison_collected"):
		powerup.poison_collected.connect(bola._on_poison_collected)
	
	# Power-up boost necesita power_amount
	if powerup.has_method("set_power_amount"):
		powerup.set_power_amount(2)
	
	var parent = get_tree().root.get_child(0)
	parent.add_child(powerup)

func _spawn_enemy(hp: int, pos: Vector2, parent: Node, game_manager: Node):
	var enemy = enemy_scene.instantiate()
	enemy.global_position = pos
	
	if enemy.has_method("set_hp"):
		enemy.set_hp(hp)
	else:
		enemy.hp = hp
	
	enemy.add_to_group("enemies")
	
	if game_manager and enemy.has_signal("enemy_destroyed"):
		enemy.enemy_destroyed.connect(game_manager._on_enemy_destroyed)
	
	parent.add_child(enemy)
