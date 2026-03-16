extends Area2D

## Lava letal en el borde inferior.
## Si la bola toca la superficie, se dispara la derrota.

const LAVA_WIDTH := 1120.0
const LAVA_DEPTH := 26.0
const TOP_OFFSET := -6.0
const WAVE_AMPLITUDE := 5.0
const SEGMENTS := 28

var elapsed := 0.0

@onready var lava_surface: Polygon2D = $LavaSurface
@onready var lava_glow: Polygon2D = $LavaGlow

func _ready():
	body_entered.connect(_on_body_entered)
	_update_lava_visual(0.0)

func _on_body_entered(body: Node):
	if not body or body.name != "Bola":
		return

	if body.has_method("die_from_combat"):
		body.die_from_combat()
	elif body.has_signal("fell"):
		body.emit_signal("fell")

func _process(delta: float):
	elapsed += delta
	_update_lava_visual(elapsed)

func _update_lava_visual(t: float):
	var top_points := PackedVector2Array()
	var step := LAVA_WIDTH / float(SEGMENTS)

	for i in range(SEGMENTS + 1):
		var x := i * step
		var primary_wave := sin(t * 3.6 + i * 0.55) * WAVE_AMPLITUDE
		var secondary_wave := sin(t * 6.4 + i * 0.22) * (WAVE_AMPLITUDE * 0.4)
		top_points.append(Vector2(x, TOP_OFFSET + primary_wave + secondary_wave))

	var lava_poly := PackedVector2Array(top_points)
	lava_poly.append(Vector2(LAVA_WIDTH, LAVA_DEPTH))
	lava_poly.append(Vector2(0.0, LAVA_DEPTH))
	lava_surface.polygon = lava_poly

	var glow_poly := PackedVector2Array()
	for p in top_points:
		glow_poly.append(Vector2(p.x, p.y - 3.0))
	glow_poly.append(Vector2(LAVA_WIDTH, 6.0))
	glow_poly.append(Vector2(0.0, 6.0))
	lava_glow.polygon = glow_poly

	var pulse := 0.5 + 0.5 * sin(t * 4.2)
	lava_surface.color = Color(0.95, 0.20 + pulse * 0.28, 0.08, 0.96)
	lava_glow.color = Color(1.0, 0.75, 0.28, 0.28 + pulse * 0.22)
