extends Node

signal difficulty_changed(stage: int)
signal ball_visual_changed(score: int, power: int)

# Referencias a los sistemas que controlaremos
@export var enemy_spawner: Node
@export var laser_spawner: Node
@export var misil_spawner: Node
@export var bola: CharacterBody2D

# Configuración de etapas de dificultad
# Cada etapa se activa cuando el score alcanza el umbral
# Regla de diseño pedida:
# - A los 10 puntos comienzan los láseres
# - A los 20 puntos aparece 1 misil
# - A los 30 puntos, 2 misiles
# - A los 50 puntos, 3 misiles
# Todo se acumula salvo la CANTIDAD de misiles, que se reemplaza
var difficulty_stages = [
	{
		"score_threshold": 0,  # Etapa inicial
		"enemy_min_hp": 1,
		"enemy_max_hp": 3,
		"enemy_spawn_interval": 2.5,
		"lasers_enabled": false,
		"misiles_enabled": false,
		"misiles_max": 0
	},
	{
		"score_threshold": 10,  # A los 10 puntos: solo se activan los láseres
		"enemy_min_hp": 2,
		"enemy_max_hp": 5,
		"enemy_spawn_interval": 2.0,
		"lasers_enabled": true,
		"misiles_enabled": false,
		"misiles_max": 0
	},
	{
		"score_threshold": 20,  # A los 20 puntos: 1 misil
		"enemy_min_hp": 3,
		"enemy_max_hp": 6,
		"enemy_spawn_interval": 1.8,
		"lasers_enabled": true,
		"misiles_enabled": true,
		"misiles_max": 1
	},
	{
		"score_threshold": 30,  # A los 30 puntos: 2 misiles
		"enemy_min_hp": 4,
		"enemy_max_hp": 7,
		"enemy_spawn_interval": 1.5,
		"lasers_enabled": true,
		"misiles_enabled": true,
		"misiles_max": 2
	},
	{
		"score_threshold": 50,  # A los 50 puntos: 3 misiles
		"enemy_min_hp": 5,
		"enemy_max_hp": 8,
		"enemy_spawn_interval": 1.2,
		"lasers_enabled": true,
		"misiles_enabled": true,
		"misiles_max": 3
	}
]

var current_stage: int = 0
var current_score: int = 0

func _ready():
	# Esperamos un frame para asegurar que todos los nodos estén listos
	await get_tree().process_frame
	
	# Resolvemos las referencias si no están asignadas
	resolve_references()
	
	# Verificamos que las referencias estén asignadas
	if not laser_spawner:
		print("ProgressionManager: ADVERTENCIA - laser_spawner no está asignado")
	if not misil_spawner:
		print("ProgressionManager: ADVERTENCIA - misil_spawner no está asignado")
	if not enemy_spawner:
		print("ProgressionManager: ADVERTENCIA - enemy_spawner no está asignado")
	
	# Inicializamos con la primera etapa (que desactiva misiles y láseres)
	apply_stage(0)
	
	# Aseguramos que los spawners estén en el estado correcto inicialmente
	if laser_spawner and laser_spawner.has_method("pause_spawning"):
		laser_spawner.pause_spawning()
	if misil_spawner and misil_spawner.has_method("pause_spawning"):
		misil_spawner.pause_spawning()
	
	# Aseguramos que max_misiles esté en 0 inicialmente
	if misil_spawner and misil_spawner.has_method("set_max_misiles"):
		misil_spawner.set_max_misiles(0)

func resolve_references():
	"""Resuelve las referencias a los spawners si no están asignadas"""
	var root = get_tree().root.get_child(0)
	
	if not enemy_spawner:
		enemy_spawner = root.get_node_or_null("EnemySpawner")
	if not laser_spawner:
		laser_spawner = root.get_node_or_null("LaserSpawner")
	if not misil_spawner:
		misil_spawner = root.get_node_or_null("MisilSpawner")
	if not bola:
		bola = root.get_node_or_null("Bola")

func update_progression(score: int, power: int):
	"""Se llama cuando cambia el score o el poder de la bola"""
	current_score = score
	
	# Determinamos qué etapa debería estar activa
	var new_stage = get_stage_for_score(score)
	
	# Aplicamos la etapa si cambió o si es la primera vez
	if new_stage != current_stage:
		current_stage = new_stage
		apply_stage(new_stage)
		emit_signal("difficulty_changed", new_stage)
		print("ProgressionManager: Cambio a etapa ", new_stage, " (score: ", score, ")")
	
	# Actualizamos la apariencia de la bola según score y poder
	update_ball_visual(score, power)

func get_stage_for_score(score: int) -> int:
	"""Determina qué etapa de dificultad corresponde al score actual"""
	var best_stage = 0
	for i in range(difficulty_stages.size()):
		if score >= difficulty_stages[i].score_threshold:
			best_stage = i
	return best_stage

func apply_stage(stage_index: int):
	"""Aplica la configuración de una etapa específica"""
	if stage_index < 0 or stage_index >= difficulty_stages.size():
		print("ProgressionManager: Etapa inválida ", stage_index)
		return
	
	# Resolvemos referencias antes de aplicar la etapa
	resolve_references()
	
	var stage = difficulty_stages[stage_index]
	print("ProgressionManager: Aplicando etapa ", stage_index, " - láseres: ", stage.lasers_enabled, ", misiles: ", stage.misiles_enabled, " (max: ", stage.misiles_max, ")")
	
	# Ajustamos dificultad de enemigos
	if enemy_spawner:
		if enemy_spawner.has_method("set_difficulty"):
			enemy_spawner.set_difficulty(stage.enemy_min_hp, stage.enemy_max_hp, stage.enemy_spawn_interval)
	
	# Activamos/desactivamos spawners según la etapa
	if laser_spawner:
		if stage.lasers_enabled:
			# Primero nos aseguramos de que esté pausado antes de resumir
			if laser_spawner.has_method("pause_spawning"):
				laser_spawner.pause_spawning()
			if laser_spawner.has_method("resume_spawning"):
				print("ProgressionManager: Activando láseres")
				laser_spawner.resume_spawning()
			else:
				print("ProgressionManager: ERROR - laser_spawner no tiene método resume_spawning")
		else:
			if laser_spawner.has_method("pause_spawning"):
				laser_spawner.pause_spawning()
	else:
		print("ProgressionManager: ERROR - laser_spawner es null")
	
	if misil_spawner:
		# Cantidad máxima de misiles activa depende de la etapa
		if misil_spawner.has_method("set_max_misiles") and "misiles_max" in stage:
			misil_spawner.set_max_misiles(stage.misiles_max)
			print("ProgressionManager: Max misiles establecido a ", stage.misiles_max)
		
		if stage.misiles_enabled and stage.misiles_max > 0:
			# Primero nos aseguramos de que esté pausado antes de resumir
			if misil_spawner.has_method("pause_spawning"):
				misil_spawner.pause_spawning()
			if misil_spawner.has_method("resume_spawning"):
				print("ProgressionManager: Activando misiles (max: ", stage.misiles_max, ")")
				misil_spawner.resume_spawning()
			else:
				print("ProgressionManager: ERROR - misil_spawner no tiene método resume_spawning")
		else:
			if misil_spawner.has_method("pause_spawning"):
				misil_spawner.pause_spawning()
				print("ProgressionManager: Desactivando misiles")
	else:
		print("ProgressionManager: ERROR - misil_spawner es null")

func update_ball_visual(score: int, power: int):
	"""Actualiza la apariencia visual de la bola según score y poder"""
	emit_signal("ball_visual_changed", score, power)
	
	if bola and bola.has_method("update_visual"):
		bola.update_visual(score, power)

func reset():
	"""Reinicia la progresión al estado inicial"""
	current_stage = 0
	current_score = 0
	apply_stage(0)
