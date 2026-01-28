extends Node

@export var bola: CharacterBody2D
@export var start_label: Label
@export var enemy_spawner: Node
@export var powerup_spawner: Node
@export var laser_spawner: Node
@export var misil_spawner: Node
@export var progression_manager: Node
@export var score_label: Label
@export var attack_power_label: Label

var spawn_position: Vector2
var score: int = 0

enum GameState {
	PLAYING,
	WAITING_TO_START
}

var state: GameState = GameState.PLAYING

func _ready():
	spawn_position = bola.global_position
	bola.fell.connect(_on_ball_fell)
	
	# Conectamos la señal de attack_power_changed si existe
	if bola.has_signal("attack_power_changed"):
		bola.attack_power_changed.connect(_on_attack_power_changed)
	
	start_label.visible = false
	update_score_display()
	update_attack_power_display()
	
	# Conectamos la señal de enemigos destruidos
	connect_enemy_signals()

func _on_ball_fell():
	state = GameState.WAITING_TO_START

	# Pausamos la bola
	bola.pause_ball()
	bola.global_position = spawn_position

	# Detenemos spawn de nuevos enemigos
	if enemy_spawner:
		enemy_spawner.pause_spawning()
	
	# Detenemos spawn de power-ups
	if powerup_spawner:
		powerup_spawner.pause_spawning()
	
	# Detenemos spawn de láseres
	if laser_spawner:
		laser_spawner.pause_spawning()
	
	# Detenemos spawn de misiles
	if misil_spawner:
		misil_spawner.pause_spawning()

	# Pausamos enemigos existentes
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("pause"):
			enemy.pause()
	
	# Pausamos láseres existentes
	for laser in get_tree().get_nodes_in_group("lasers"):
		if laser.has_method("pause"):
			laser.pause()
	
	# Pausamos misiles existentes
	for misil in get_tree().get_nodes_in_group("misiles"):
		if misil.has_method("pause"):
			misil.pause()

	start_label.visible = true

func _input(event):
	if state != GameState.WAITING_TO_START:
		return

	if (event is InputEventScreenTouch and event.pressed) \
	or (event is InputEventMouseButton and event.pressed):
		start_game()

func start_game():
	start_label.visible = false
	state = GameState.PLAYING
	
	# Reiniciamos los puntos
	score = 0
	update_score_display()

	# Reiniciamos spawn y eliminamos enemigos
	if enemy_spawner:
		enemy_spawner.reset()
		enemy_spawner.resume_spawning()
	
	# Reiniciamos spawn y eliminamos power-ups
	if powerup_spawner:
		powerup_spawner.reset()
		powerup_spawner.resume_spawning()
	
	# Reiniciamos spawn y eliminamos láseres
	if laser_spawner:
		laser_spawner.reset()
		# No lo activamos aquí, el ProgressionManager lo hará según el score
	
	# Reiniciamos spawn y eliminamos misiles
	if misil_spawner:
		misil_spawner.reset()
		# No lo activamos aquí, el ProgressionManager lo hará según el score

	# Reanudamos la bola (esto también reinicia el attack_power)
	bola.resume_ball()
	
	# Actualizamos el display del attack_power
	update_attack_power_display()
	
	# Reconectamos señales de enemigos
	connect_enemy_signals()
	
	# Reiniciamos el ProgressionManager (esto configurará todo según el score inicial)
	if progression_manager and progression_manager.has_method("reset"):
		progression_manager.reset()
		# Actualizamos con el estado inicial (score = 0)
		var initial_power = bola.get("attack_power") if bola else 5
		progression_manager.update_progression(score, initial_power)

func connect_enemy_signals():
	# Desconectamos señales anteriores para evitar duplicados
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_signal("enemy_destroyed"):
			if not enemy.enemy_destroyed.is_connected(_on_enemy_destroyed):
				enemy.enemy_destroyed.connect(_on_enemy_destroyed)

func _on_enemy_destroyed():
	score += 1
	update_score_display()
	
	# Notificamos al ProgressionManager del cambio de score
	if progression_manager and progression_manager.has_method("update_progression"):
		var current_power = bola.get("attack_power") if bola else 5
		progression_manager.update_progression(score, current_power)

func update_score_display():
	if score_label:
		score_label.text = "Score: " + str(score)

func update_attack_power_display():
	if attack_power_label and bola:
		# Accedemos directamente a la propiedad attack_power de la bola
		var current_power = bola.get("attack_power")
		if current_power != null:
			attack_power_label.text = "Power: " + str(current_power)

func _on_attack_power_changed(new_power: int):
	update_attack_power_display()
	
	# Notificamos al ProgressionManager del cambio de poder
	if progression_manager and progression_manager.has_method("update_progression"):
		progression_manager.update_progression(score, new_power)
