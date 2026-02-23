# Diseño: Power-up Escudo

## Resumen

Power-up de **escudo** que se activa automáticamente al recogerlo. Protege la bola del siguiente misil o láser que la golpee, absorbiendo el impacto y desapareciendo (uso único). Dura un tiempo limitado; si no recibe impacto, expira.

---

## 1. Item collectible (antes del pickup)

### Visual
- **Forma**: Icono de escudo pequeño y reconocible
- **Tamaño**: ~30×30 px (legible en móvil)
- **Color base**: Azul cian/plateado (`#4FC3F7` o similar)
- **Efecto de brillo**: Glow suave pulsante (opacidad 0.6–1.0, ciclo ~1.2 s)
- **Contraste**: Borde más oscuro para silueta clara

### Implementación sugerida (Godot)
- `Polygon2D` con forma de escudo (hexágono/forma de escudo heráldico)
- `Modulate` animado con `Tween` para el pulso
- Alternativa: `Sprite2D` con textura de escudo si se añaden assets

---

## 2. Escudo activo en la bola

### Estados visuales

| Estado | Descripción | Duración aproximada |
|--------|-------------|----------------------|
| **Idle / Active** | Halo suave alrededor de la bola, pulso lento | Hasta ~2 s antes de expirar |
| **About to expire** | Aura parpadea o se desvanece | Últimos ~2 s |
| **Absorbing impact** | Flash o shockwave al bloquear, luego desaparece | ~0.3–0.5 s |

### Idle / Active
- **Forma**: Círculo/aura concéntrico alrededor de la bola
- **Color**: Azul cian translúcido (`Color(0.31, 0.76, 0.97, 0.4)`)
- **Animación**: Pulso lento de escala/opacidad (1.0 → 1.15 → 1.0, ciclo ~1.5 s)
- **Espesor**: Línea fina (~3–5 px) para no tapar la bola

### About to expire
- **Efecto**: Parpadeo (opacidad 0.2 ↔ 0.6) cada ~0.3 s
- **Alternativa**: Desvanecimiento gradual o cambio de color (cian → amarillo suave)
- **Objetivo**: Avisar al jugador de que el escudo está por terminar

### Absorbing impact
- **Trigger**: Cuando un misil o láser golpea la bola con escudo activo
- **Secuencia**:
  1. Flash blanco/cyan breve (~0.1 s)
  2. Onda expansiva (círculo que crece y se desvanece)
  3. Desaparición del aura
- **Feedback**: Satisfactorio y claro para que el jugador entienda que bloqueó el ataque

---

## 3. Especificaciones técnicas

### Parámetros
- **Duración del escudo**: 8–10 s (configurable)
- **Tiempo de aviso “about to expire”**: 2 s antes de expirar
- **Uso**: Un solo impacto (misil o láser) antes de desaparecer

### Integración con el juego
- **Bola**: Variable `has_shield: bool`, `shield_timer: Timer`
- **Láser/Misil**: Antes de aplicar daño, comprobar `bola.has_shield`; si es true, consumir escudo y no reducir `attack_power`
- **Spawner**: Añadir `ShieldPowerUp` al pool de power-ups (p. ej. 25–30 % de probabilidad)

### Señales
- `shield_activated(duration: float)` — Escudo activado
- `shield_absorbed_hit()` — Escudo bloqueó un impacto
- `shield_expired()` — Escudo expiró por tiempo

---

## 4. Diagrama de estados

```
[Recogido] → [Idle/Active] ──(impacto)──→ [Absorbing] → [Fin]
                  │
                  └──(tiempo)──→ [About to expire] ──(tiempo)──→ [Fin]
```

---

## 5. Archivos a crear/modificar

| Archivo | Acción |
|---------|--------|
| `Scripts/shield_powerup.gd` | Nuevo — Lógica del item escudo |
| `Scripts/shield_aura.gd` | Nuevo — Efecto visual en la bola |
| `Scenes/ShieldPowerUp.tscn` | Nuevo — Escena del item |
| `Scripts/bola.gd` | Modificar — Lógica de escudo y uso en `_on_laser_hit` / `_on_misil_hit` |
| `Scripts/powerupspawner.gd` | Modificar — Spawn de escudo además del boost |
| `Scenes/bola.tscn` | Modificar — Añadir nodo `ShieldAura` (oculto por defecto) |
