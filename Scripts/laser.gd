class_name Laser
extends Area2D

signal laser_hit(power_loss: int)

@export var charge_time := 2.0  # Tiempo de carga antes de activarse
@export var active_duration := 1.0  # Tiempo que el láser permanece activo (1 segundo)
@export var power_loss := 3  # Cantidad de poder que reduce
@export var laser_width := 5.0  # Ancho del láser
@export var warning_color := Color(1.0, 0.5, 0.0, 0.7)  # Color naranja durante carga
@export var active_color := Color(1.0, 0.0, 0.0, 1.0)  # Color rojo cuando está activo

var is_active := false
var charge_timer: Timer
var active_timer: Timer
var line: Line2D
var collision_shape: CollisionShape2D
var blink_timer: Timer
var start_point: Vector2  # Punto de inicio del láser (en coordenadas globales)
var end_point: Vector2  # Punto de fin del láser (en coordenadas globales)
var laser_direction: Vector2  # Dirección normalizada del láser

func _ready():
	# Usamos call_deferred para asegurar que el viewport esté completamente inicializado
	call_deferred("_initialize_laser")

func _initialize_laser():
	# Calculamos los puntos de inicio y fin del láser diagonal
	_calculate_diagonal_points()
	
	# Creamos el timer para la carga
	charge_timer = Timer.new()
	charge_timer.wait_time = charge_time
	charge_timer.one_shot = true
	charge_timer.timeout.connect(_on_charge_complete)
	add_child(charge_timer)
	
	# Creamos un timer para el parpadeo durante la carga
	blink_timer = Timer.new()
	blink_timer.wait_time = 0.2  # Parpadea cada 0.2 segundos
	blink_timer.timeout.connect(_on_blink)
	add_child(blink_timer)
	blink_timer.start()
	
	# Creamos la línea visual
	line = Line2D.new()
	line.width = laser_width
	line.default_color = warning_color
	line.z_index = 10  # Aseguramos que esté por encima de otros elementos
	add_child(line)
	
	# Configuramos los puntos de la línea diagonal
	_create_line_points()
	
	# Debug: verificamos que la línea tenga puntos
	if line.get_point_count() == 0:
		print("ERROR: La línea no tiene puntos!")
	else:
		print("Línea creada con ", line.get_point_count(), " puntos")
	
	# Creamos el área de colisión diagonal
	_create_collision_shape()
	
	# Conectamos la señal de colisión
	body_entered.connect(_on_body_entered)
	
	# Iniciamos el timer de carga
	charge_timer.start()
	
	# Configuramos la línea punteada inicialmente
	_update_line_appearance()

func _calculate_diagonal_points():
	"""Calcula puntos de inicio y fin en bordes opuestos de la pantalla para crear una diagonal que pase por la bola"""
	var viewport = get_viewport_rect()
	var screen_size = viewport.size
	
	# Obtenemos la posición de la bola
	var root = get_tree().root.get_child(0)
	var bola = root.get_node_or_null("Bola")
	var ball_pos = bola.global_position if bola else Vector2(screen_size.x / 2, screen_size.y / 2)
	
	# Elegimos un ángulo diagonal aleatorio (entre 30° y 60° o 120° y 150° para evitar vertical/horizontal)
	var angle = randf_range(PI / 6, PI / 3)  # Entre 30° y 60°
	if randf() > 0.5:
		angle = PI - angle  # Invertimos para tener dirección opuesta
	
	# Dirección del láser
	var direction = Vector2(cos(angle), sin(angle))
	
	# Calculamos dónde intersecta esta línea (que pasa por la bola) con los bordes de la pantalla
	var margin = 10.0
	var intersections = []
	
	# Borde izquierdo (x = margin)
	if abs(direction.x) > 0.001:
		var t_left = (margin - ball_pos.x) / direction.x
		var y = ball_pos.y + direction.y * t_left
		if y >= -margin and y <= screen_size.y + margin:
			intersections.append(ball_pos + direction * t_left)
	
	# Borde derecho (x = screen_size.x - margin)
	if abs(direction.x) > 0.001:
		var t_right = (screen_size.x - margin - ball_pos.x) / direction.x
		var y = ball_pos.y + direction.y * t_right
		if y >= -margin and y <= screen_size.y + margin:
			intersections.append(ball_pos + direction * t_right)
	
	# Borde superior (y = margin)
	if abs(direction.y) > 0.001:
		var t_top = (margin - ball_pos.y) / direction.y
		var x = ball_pos.x + direction.x * t_top
		if x >= -margin and x <= screen_size.x + margin:
			intersections.append(ball_pos + direction * t_top)
	
	# Borde inferior (y = screen_size.y - margin)
	if abs(direction.y) > 0.001:
		var t_bottom = (screen_size.y - margin - ball_pos.y) / direction.y
		var x = ball_pos.x + direction.x * t_bottom
		if x >= -margin and x <= screen_size.x + margin:
			intersections.append(ball_pos + direction * t_bottom)
	
	# Eliminamos duplicados y puntos fuera de rango
	var valid_intersections = []
	for intersection in intersections:
		if intersection.x >= -margin and intersection.x <= screen_size.x + margin and \
		   intersection.y >= -margin and intersection.y <= screen_size.y + margin:
			var is_duplicate = false
			for existing in valid_intersections:
				if intersection.distance_to(existing) < 5.0:
					is_duplicate = true
					break
			if not is_duplicate:
				valid_intersections.append(intersection)
	
	# Si tenemos al menos 2 intersecciones, usamos las más lejanas
	if valid_intersections.size() >= 2:
		# Encontramos las dos más lejanas entre sí
		var max_dist = 0.0
		var best_start = valid_intersections[0]
		var best_end = valid_intersections[1]
		
		for i in range(valid_intersections.size()):
			for j in range(i + 1, valid_intersections.size()):
				var dist = valid_intersections[i].distance_to(valid_intersections[j])
				if dist > max_dist:
					max_dist = dist
					best_start = valid_intersections[i]
					best_end = valid_intersections[j]
		
		start_point = best_start
		end_point = best_end
	else:
		# Fallback: línea diagonal simple desde esquinas opuestas que pase por la bola
		var corners = [
			Vector2(margin, margin),
			Vector2(screen_size.x - margin, margin),
			Vector2(screen_size.x - margin, screen_size.y - margin),
			Vector2(margin, screen_size.y - margin)
		]
		# Elegimos esquinas opuestas
		var corner_indices = [
			[0, 2],  # Esquina superior izquierda a inferior derecha
			[1, 3]   # Esquina superior derecha a inferior izquierda
		]
		var pair = corner_indices[randi() % 2]
		var corner1 = corners[pair[0]]
		var corner2 = corners[pair[1]]
		
		# Calculamos la línea que pasa por ambos puntos
		var line_dir = (corner2 - corner1).normalized()
		var perp = Vector2(-line_dir.y, line_dir.x)
		
		# Proyectamos la bola sobre la línea
		var t = line_dir.dot(ball_pos - corner1) / line_dir.dot(line_dir)
		var closest_on_line = corner1 + line_dir * t
		
		# Ajustamos la línea para que pase por la bola
		var offset = ball_pos - closest_on_line
		start_point = corner1 + offset
		end_point = corner2 + offset
		
		# Aseguramos que estén en los bordes
		start_point = _clamp_to_screen_edge(start_point, screen_size)
		end_point = _clamp_to_screen_edge(end_point, screen_size)
	
	# Aseguramos que sea diagonal (tiene componente tanto X como Y significativa)
	var final_direction = end_point - start_point
	if abs(final_direction.x) < 20 or abs(final_direction.y) < 20:
		# Si es casi vertical u horizontal, lo ajustamos
		var new_angle = randf_range(PI / 6, PI / 3)
		if randf() > 0.5:
			new_angle = PI - new_angle
		var new_dir = Vector2(cos(new_angle), sin(new_angle))
		var length = max(screen_size.x, screen_size.y) * 1.5
		start_point = ball_pos - new_dir * length / 2
		end_point = ball_pos + new_dir * length / 2
		
		# Ajustamos para que toque los bordes
		start_point = _clamp_to_screen_edge(start_point, screen_size)
		end_point = _clamp_to_screen_edge(end_point, screen_size)
		final_direction = end_point - start_point
	
	laser_direction = final_direction.normalized()
	
	# Posicionamos el nodo en el punto medio del láser
	global_position = (start_point + end_point) / 2
	
	# Convertimos los puntos a coordenadas locales
	start_point = start_point - global_position
	end_point = end_point - global_position
	
	# Debug
	print("Láser - Start: ", start_point + global_position, " End: ", end_point + global_position, " Global pos: ", global_position)

func _clamp_to_screen_edge(point: Vector2, screen_size: Vector2) -> Vector2:
	"""Ajusta un punto para que esté en el borde de la pantalla"""
	var margin = 10.0
	var clamped = point
	
	# Determinamos qué borde está más cerca
	var dist_to_left = abs(clamped.x - margin)
	var dist_to_right = abs(clamped.x - (screen_size.x - margin))
	var dist_to_top = abs(clamped.y - margin)
	var dist_to_bottom = abs(clamped.y - (screen_size.y - margin))
	
	var min_dist = min(dist_to_left, dist_to_right, dist_to_top, dist_to_bottom)
	
	if min_dist == dist_to_left:
		clamped.x = margin
	elif min_dist == dist_to_right:
		clamped.x = screen_size.x - margin
	elif min_dist == dist_to_top:
		clamped.y = margin
	else:
		clamped.y = screen_size.y - margin
	
	return clamped

func _create_line_points():
	"""Crea los puntos de la línea diagonal, punteada durante carga o continua cuando está activo"""
	if not line:
		return
		
	line.clear_points()
	
	if is_active:
		# Línea continua cuando está activo
		line.add_point(start_point)
		line.add_point(end_point)
	else:
		# Línea punteada durante la carga (segmentos pequeños separados)
		var segment_length = 20.0  # Longitud de cada segmento
		var gap_length = 15.0  # Espacio entre segmentos
		var total_length = start_point.distance_to(end_point)
		var current_pos = 0.0
		var direction_vec = (end_point - start_point).normalized()
		
		while current_pos < total_length:
			var segment_start = start_point + direction_vec * current_pos
			current_pos += segment_length
			var segment_end = start_point + direction_vec * min(current_pos, total_length)
			line.add_point(segment_start)
			line.add_point(segment_end)
			current_pos += gap_length
	
	# Debug
	print("Línea actualizada - puntos: ", line.get_point_count(), " start: ", start_point, " end: ", end_point)

func _create_collision_shape():
	"""Crea la forma de colisión diagonal usando un polígono"""
	var total_length = start_point.distance_to(end_point)
	var perp_direction = Vector2(-laser_direction.y, laser_direction.x)  # Perpendicular
	var half_width = laser_width / 2.0
	
	# Creamos un polígono rectangular rotado
	var polygon_points = PackedVector2Array()
	polygon_points.append(start_point + perp_direction * half_width)
	polygon_points.append(start_point - perp_direction * half_width)
	polygon_points.append(end_point - perp_direction * half_width)
	polygon_points.append(end_point + perp_direction * half_width)
	
	var shape = ConvexPolygonShape2D.new()
	shape.points = polygon_points
	
	collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	add_child(collision_shape)

func _update_line_appearance():
	"""Actualiza la apariencia de la línea según el estado"""
	if not line:
		return
		
	if is_active:
		# Línea continua cuando está activo
		line.default_color = active_color
		line.modulate.a = 1.0
		if blink_timer:
			blink_timer.stop()
	else:
		# Línea punteada durante la carga
		line.default_color = warning_color

func _on_blink():
	"""Hace parpadear la línea durante la carga"""
	if is_active:
		return
	# Alternamos la visibilidad para crear efecto de parpadeo
	line.modulate.a = 0.3 if line.modulate.a > 0.5 else 0.8

func _on_charge_complete():
	"""Se llama cuando termina el tiempo de carga"""
	is_active = true
	_create_line_points()  # Recreamos los puntos para línea continua
	_update_line_appearance()
	
	# Creamos un timer para destruir el láser después de estar activo
	active_timer = Timer.new()
	active_timer.wait_time = active_duration
	active_timer.one_shot = true
	active_timer.timeout.connect(_on_active_timeout)
	add_child(active_timer)
	active_timer.start()

func _on_active_timeout():
	"""Se llama cuando el láser ha estado activo el tiempo suficiente"""
	queue_free()

func _on_body_entered(body: Node2D):
	"""Se llama cuando algo entra en el área del láser"""
	if not is_active:
		return  # No hace daño durante la carga
		
	# Solo reaccionamos si es la bola del jugador
	if body.name == "Bola":
		emit_signal("laser_hit", power_loss)

func set_laser_position(x_position: float):
	"""Establece la posición de referencia del láser (ya no se usa para posición X específica)"""
	# Este método se mantiene por compatibilidad pero ahora el láser se posiciona automáticamente
	# en _calculate_diagonal_points()
	pass

func pause():
	"""Pausa el láser"""
	if charge_timer:
		charge_timer.paused = true
	if active_timer:
		active_timer.paused = true
	if blink_timer:
		blink_timer.paused = true
	set_process(false)

func resume():
	"""Reanuda el láser"""
	if charge_timer:
		charge_timer.paused = false
	if active_timer:
		active_timer.paused = false
	if blink_timer:
		blink_timer.paused = false
	set_process(true)
