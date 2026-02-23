extends Control

## Pantalla inicial con Play y Debug mode.
## Emite señales cuando el usuario elige una opción.

signal play_pressed
signal debug_mode_pressed

func _ready():
	var play_btn = get_node_or_null("VBox/PlayButton")
	var debug_btn = get_node_or_null("VBox/DebugButton")
	if play_btn:
		play_btn.pressed.connect(_on_play_pressed)
	if debug_btn:
		debug_btn.pressed.connect(_on_debug_pressed)

func _on_play_pressed():
	emit_signal("play_pressed")

func _on_debug_pressed():
	emit_signal("debug_mode_pressed")
