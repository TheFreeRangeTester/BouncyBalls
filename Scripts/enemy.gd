class_name Enemy
extends StaticBody2D

signal enemy_destroyed

@export var speed: float = 100.0
@export var hp: int = 3

var direction := 1
var min_x: float
var max_x: float
var is_dying := false  # Bandera para evitar múltiples llamadas a die()
var hp_label: Label

# Veneno: -1 hp por segundo durante 3 segundos, no apilable
var is_poisoned := false
var poison_tick_timer: Timer
var poison_ticks_remaining := 0
const POISON_DURATION_SECONDS := 3
const POISON_DAMAGE_PER_TICK := 1

func _ready():
	# Buscamos el label de HP
	hp_label = get_node_or_null("HPLabel")
	
	# Calculamos los límites basándonos en las paredes de la escena
	calculate_limits()
	
	# Actualizamos el label con el HP inicial
	update_hp_display()

func calculate_limits():
	# Buscamos el nodo raíz de la escena (Main)
	var root = get_tree().root.get_child(0)
	
	# Buscamos el nodo Walls
	var walls = root.get_node_or_null("Walls")
	
	if walls:
		var left_wall = walls.get_node_or_null("LeftWall")
		var right_wall = walls.get_node_or_null("RightWall")
		
		if left_wall and right_wall:
			var left_collision = left_wall.get_node_or_null("CollisionShape2D")
			var right_collision = right_wall.get_node_or_null("CollisionShape2D")
			
			if left_collision and right_collision:
				# Obtenemos el ancho de cada pared (extents es la mitad del tamaño)
				var left_wall_width = left_collision.shape.size.x
				var right_wall_width = right_collision.shape.size.x
				
				# Consideramos la posición del CollisionShape2D relativa a su padre
				var left_wall_x = left_wall.global_position.x + left_collision.position.x
				var right_wall_x = right_wall.global_position.x + right_collision.position.x
				
				# min_x es el borde derecho de la pared izquierda
				min_x = left_wall_x + left_wall_width / 2
				# max_x es el borde izquierdo de la pared derecha
				max_x = right_wall_x - right_wall_width / 2
				return
	
	# Fallback: usar valores por defecto si no encontramos paredes
	var viewport = get_viewport_rect()
	min_x = 50
	max_x = viewport.size.x - 50

func _physics_process(delta):
	var half_width = $CollisionShape2D.shape.extents.x * global_scale.x
	
	# Calculamos la próxima posición antes de mover
	var next_x = global_position.x + speed * direction * delta
	var next_left = next_x - half_width
	var next_right = next_x + half_width
	
	# Verificamos si la próxima posición saldría de los límites
	if next_left <= min_x:
		# Rebotamos en la pared izquierda
		global_position.x = min_x + half_width
		direction = 1  # Cambiamos a dirección derecha
	elif next_right >= max_x:
		# Rebotamos en la pared derecha
		global_position.x = max_x - half_width
		direction = -1  # Cambiamos a dirección izquierda
	else:
		# Movemos normalmente si no hay colisión
		global_position.x = next_x

func take_damage(amount: int):
	if is_dying:
		return  # Ya está muriendo, ignoramos más daño
	
	hp -= amount
	if hp <= 0:
		die()

func apply_poison() -> bool:
	"""Aplica veneno al enemigo. Retorna true si se aplicó, false si ya estaba envenenado (no apilable)."""
	if is_poisoned:
		return false
	if is_dying:
		return false
	
	is_poisoned = true
	poison_ticks_remaining = POISON_DURATION_SECONDS
	
	if poison_tick_timer:
		poison_tick_timer.stop()
		poison_tick_timer.queue_free()
	
	poison_tick_timer = Timer.new()
	poison_tick_timer.wait_time = 1.0
	poison_tick_timer.timeout.connect(_on_poison_tick)
	add_child(poison_tick_timer)
	poison_tick_timer.start()
	
	return true

func _on_poison_tick():
	poison_ticks_remaining -= 1
	hp = max(0, hp - POISON_DAMAGE_PER_TICK)
	update_hp_display()
	
	_show_floating_damage(POISON_DAMAGE_PER_TICK)
	
	if hp <= 0:
		die()
		return
	
	if poison_ticks_remaining <= 0:
		is_poisoned = false
		if poison_tick_timer:
			poison_tick_timer.stop()
			poison_tick_timer.queue_free()
			poison_tick_timer = null

func die():
	if is_dying:
		return  # Ya está muriendo, evitamos llamadas múltiples
	
	is_dying = true
	emit_signal("enemy_destroyed")
	queue_free()

func pause():
	set_physics_process(false)

func resume():
	set_physics_process(true)

func set_hp(new_hp: int):
	"""Establece el HP del enemigo y actualiza el display"""
	hp = new_hp
	update_hp_display()

func update_hp_display():
	"""Actualiza el label para mostrar el HP actual"""
	if hp_label:
		hp_label.text = str(hp)

func _show_floating_damage(amount: int):
	"""Muestra un número flotante de daño sobre el enemigo (-1, -2, etc.)"""
	var container = Node2D.new()
	var label = Label.new()
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0.2, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 2)
	container.add_child(label)
	label.position = Vector2(-25, -40)
	label.size = Vector2(50, 35)
	
	var parent = get_parent()
	if not parent:
		return
	parent.add_child(container)
	container.global_position = global_position + Vector2(0, -25)
	container.z_index = 10
	
	var tween = container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(container, "position", container.position + Vector2(0, -40), 0.7)
	tween.tween_property(container, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(container.queue_free)
