class_name ShieldAura
extends Node2D

## Efecto visual del escudo alrededor de la bola.
## Estados: Idle (pulso), About to expire (parpadeo), Absorbing (flash + burst).

enum State { IDLE, ABOUT_TO_EXPIRE, ABSORBING }

@export var pulse_cycle := 1.5
@export var expire_warning_time := 2.0  # Segundos antes de expirar para mostrar aviso
@export var absorb_duration := 0.35

var state := State.IDLE
var time_remaining := 0.0
var pulse_tween: Tween
var expire_tween: Tween

var _line: Line2D
var _parent: Node2D

func _ready():
	_parent = get_parent()
	_create_aura_line()
	visible = false

func _create_aura_line():
	"""Crea un círculo alrededor del centro de la bola"""
	_line = Line2D.new()
	_line.width = 4.0
	_line.default_color = Color(0.31, 0.76, 0.97, 0.5)
	_line.z_index = 5
	
	# Círculo con ~32 puntos
	var points = PackedVector2Array()
	var radius = 35.0  # Un poco más grande que la bola
	for i in range(33):
		var angle = (float(i) / 32.0) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	_line.points = points
	add_child(_line)

func activate(duration: float):
	"""Activa el escudo con la duración indicada"""
	time_remaining = duration
	state = State.IDLE
	visible = true
	_start_idle_pulse()

func _start_idle_pulse():
	"""Pulso suave en estado Idle"""
	if pulse_tween:
		pulse_tween.kill()
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(self, "scale", Vector2(1.08, 1.08), pulse_cycle / 2)
	pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), pulse_cycle / 2)

func _process(delta):
	if not visible or state == State.ABSORBING:
		return
	
	time_remaining -= delta
	
	# Transición a "about to expire"
	if state == State.IDLE and time_remaining <= expire_warning_time:
		state = State.ABOUT_TO_EXPIRE
		_start_expire_flicker()

func _start_expire_flicker():
	"""Parpadeo cuando está por expirar"""
	if pulse_tween:
		pulse_tween.kill()
	
	if expire_tween:
		expire_tween.kill()
	
	expire_tween = create_tween()
	expire_tween.set_loops()
	expire_tween.tween_property(_line, "modulate:a", 0.25, 0.25)
	expire_tween.tween_property(_line, "modulate:a", 0.7, 0.25)

func play_absorb_animation():
	"""Reproduce el efecto de absorción al bloquear un impacto"""
	state = State.ABSORBING
	
	if pulse_tween:
		pulse_tween.kill()
	if expire_tween:
		expire_tween.kill()
	
	# Flash breve + onda expansiva
	_line.default_color = Color(1.0, 1.0, 1.0, 1.0)
	_line.width = 6.0
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.1)
	tween.parallel().tween_property(_line, "modulate:a", 0.0, absorb_duration)
	tween.tween_callback(_deactivate)

func _deactivate():
	visible = false
	state = State.IDLE
	scale = Vector2.ONE
	_line.modulate.a = 1.0
	_line.default_color = Color(0.31, 0.76, 0.97, 0.5)
	_line.width = 4.0
	
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null
	if expire_tween:
		expire_tween.kill()
		expire_tween = null
