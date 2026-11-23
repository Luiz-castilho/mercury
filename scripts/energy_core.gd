class_name EnergyCore
extends Area2D
## Núcleo de energia no chão da arena (Godot 4.x). É elemento do cenário: guarda
## a bateria, que o chefe expõe ao fazer um ataque perto dele (fase 2).
## Enquanto exposta, bater nela machuca o chefe. Depois do tempo, fecha de novo.
##
## Estrutura:
##   EnergyCore (Area2D)      <- este script
##   ├── CollisionShape2D
##   ├── ClosedVisual (Sprite2D)   -> "closed_visual" (núcleo fechado)
##   └── BatteryVisual (Sprite2D)  -> "battery_visual" (bateria saltada)
## A camada deste Area2D deve estar na máscara da AttackArea (e da DownAttackArea)
## do jogador.

signal exposed
signal concealed
signal battery_hit(amount: int)

@export var closed_visual: CanvasItem
@export var battery_visual: CanvasItem
@export var collision: CollisionShape2D

var is_exposed := false
var _remaining := 0.0


func _ready() -> void:
	print("TESTE BATERIA -> close: ", closed_visual, " | open: ", battery_visual)
	add_to_group("energy_core")
	_update_visuals()
	collision.set_deferred("disabled", false)


func _process(delta: float) -> void:
	if is_exposed:
		_remaining -= delta
		if _remaining <= 0.0:
			conceal()


func expose(duration: float) -> void:
	is_exposed = true
	_remaining = duration
	_update_visuals()
	exposed.emit()


func conceal() -> void:
	if not is_exposed:
		return
	is_exposed = false
	_update_visuals()
	concealed.emit()


## O jogador chama isto ao atacar. Só conta se a bateria estiver exposta.
func take_damage(amount: int, _from_position := Vector2.ZERO) -> void:
	if not is_exposed:
		return
	battery_hit.emit(amount)
	if battery_visual:
		battery_visual.modulate = Color(2.0, 2.0, 2.0)
		create_tween().tween_property(battery_visual, "modulate", Color.WHITE, 0.15)


func _update_visuals() -> void:
	if closed_visual:
		closed_visual.visible = not is_exposed
	if battery_visual:
		battery_visual.visible = is_exposed
	set_deferred("monitorable", is_exposed)
	
