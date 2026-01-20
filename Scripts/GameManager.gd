extends Node

@export var bola: CharacterBody2D
@export var start_label: Label
@export var enemy_spawner: Node
@export var score_label: Label

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
	start_label.visible = false
	update_score_display()
	
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

	# Pausamos enemigos existentes
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("pause"):
			enemy.pause()

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

	# Reanudamos la bola
	bola.resume_ball()
	
	# Reconectamos señales de enemigos
	connect_enemy_signals()

func connect_enemy_signals():
	# Desconectamos señales anteriores para evitar duplicados
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_signal("enemy_destroyed"):
			if not enemy.enemy_destroyed.is_connected(_on_enemy_destroyed):
				enemy.enemy_destroyed.connect(_on_enemy_destroyed)

func _on_enemy_destroyed():
	score += 1
	update_score_display()

func update_score_display():
	if score_label:
		score_label.text = "Score: " + str(score)
