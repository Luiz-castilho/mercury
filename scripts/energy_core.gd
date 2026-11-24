class_name EnergyCore
extends Area2D
## Núcleo de energia no chão da arena (Godot 4.x). É elemento do cenário: guarda
## uma bateria que o chefe expõe ao mergulhar perto dela (fase 2).
##
## ESTADOS
##   INACTIVE   desligado: não pode ser exposto (fica assim até a fase 2 começar)
##   ARMED      ligado e fechado, esperando o mergulho do chefe
##   EXPOSED    bateria saltada: cada golpe do jogador conta como um acerto
##   DESTROYED  destruída de vez (depois de "max_hits" acertos)
## Cada bateria destruída tira uma parte da vida do chefe (veja boss.gd).
##
## Estrutura (todos os visuais são opcionais; sem arte, o script só escurece o
## "closed_visual" no estado DESTROYED; INACTIVE usa a mesma arte da fechada):
##   EnergyCore (Area2D)          <- este script
##   ├── CollisionShape2D
##   ├── InactiveVisual (Sprite2D)  -> "inactive_visual"  (desligada)
##   ├── ClosedVisual (Sprite2D)    -> "closed_visual"    (ligada, fechada)
##   ├── BatteryVisual (Sprite2D)   -> "battery_visual"   (bateria exposta)
##   └── DestroyedVisual (Sprite2D) -> "destroyed_visual" (destruída)
## A camada deste Area2D deve estar na máscara da AttackArea (e da DownAttackArea)
## do jogador.

enum CoreState { INACTIVE, ARMED, EXPOSED, DESTROYED }

signal activated
signal exposed
signal concealed
signal damaged(hits_left: int)
signal battery_hit(amount: int)
signal destroyed

## Acertos necessários, com a bateria exposta, para destruí-la.
@export var max_hits := 3
## Se verdadeiro, começa desligada e só liga quando o chefe chama activate().
@export var start_inactive := true
## Pausa mínima entre dois acertos (evita contar o mesmo golpe duas vezes).
@export var hit_cooldown := 0.35
## Se verdadeiro, a bateria "cura" os acertos quando se fecha de novo.
@export var reset_hits_on_conceal := false

@export_group("Visuais (opcionais)")
@export var inactive_visual: CanvasItem
@export var closed_visual: CanvasItem
@export var battery_visual: CanvasItem
@export var destroyed_visual: CanvasItem
@export var collision: CollisionShape2D

var state := CoreState.INACTIVE
var hits_left := 0
var is_exposed: bool:
	get:
		return state == CoreState.EXPOSED

var _remaining := 0.0
var _cooldown := 0.0


func _ready() -> void:
	add_to_group("energy_core")
	hits_left = max_hits
	state = CoreState.INACTIVE if start_inactive else CoreState.ARMED
	if collision:
		collision.set_deferred("disabled", false)
	_update_visuals()


func _process(delta: float) -> void:
	_cooldown -= delta
	if state == CoreState.EXPOSED:
		_remaining -= delta
		if _remaining <= 0.0:
			conceal()


## Liga a bateria (o chefe chama no começo da fase 2).
func activate() -> void:
	if state != CoreState.INACTIVE:
		return
	state = CoreState.ARMED
	_update_visuals()
	activated.emit()


func can_be_exposed() -> bool:
	return state == CoreState.ARMED


func is_destroyed() -> bool:
	return state == CoreState.DESTROYED


func expose(duration: float) -> void:
	if state != CoreState.ARMED:
		return
	state = CoreState.EXPOSED
	_remaining = duration
	_update_visuals()
	exposed.emit()


func conceal() -> void:
	if state != CoreState.EXPOSED:
		return
	state = CoreState.ARMED
	if reset_hits_on_conceal:
		hits_left = max_hits
	_update_visuals()
	concealed.emit()


## O jogador chama isto ao atacar. Só conta se a bateria estiver exposta.
func take_damage(amount: int, _from_position := Vector2.ZERO) -> void:
	if state != CoreState.EXPOSED or _cooldown > 0.0:
		return
	_cooldown = hit_cooldown
	hits_left = maxi(hits_left - 1, 0)
	battery_hit.emit(amount)
	damaged.emit(hits_left)
	if battery_visual:
		battery_visual.modulate = Color(2.0, 2.0, 2.0)
		create_tween().tween_property(battery_visual, "modulate", Color.WHITE, 0.15)
	if hits_left <= 0:
		_destroy()


func _destroy() -> void:
	state = CoreState.DESTROYED
	_update_visuals()
	destroyed.emit()


func _update_visuals() -> void:
	var has_inactive := _has_art(inactive_visual)
	var has_destroyed := _has_art(destroyed_visual)
	if inactive_visual:
		inactive_visual.visible = state == CoreState.INACTIVE and has_inactive
	if destroyed_visual:
		destroyed_visual.visible = state == CoreState.DESTROYED and has_destroyed
	if battery_visual:
		battery_visual.visible = state == CoreState.EXPOSED
	if closed_visual:
		var show_closed := state == CoreState.ARMED
		var tint := Color.WHITE
		if state == CoreState.INACTIVE and not has_inactive:
			show_closed = true  # sem arte própria: igual à fechada (sem escurecer)
		elif state == CoreState.DESTROYED and not has_destroyed:
			show_closed = true
			tint = Color(0.28, 0.12, 0.12)  # sem arte própria: fica queimada
		closed_visual.visible = show_closed
		closed_visual.modulate = tint
	# Só dá para acertar a bateria enquanto ela está exposta.
	set_deferred("monitorable", state == CoreState.EXPOSED)


func _has_art(node: CanvasItem) -> bool:
	if node == null:
		return false
	if node is Sprite2D:
		return (node as Sprite2D).texture != null
	if node is AnimatedSprite2D:
		return (node as AnimatedSprite2D).sprite_frames != null
	return true
