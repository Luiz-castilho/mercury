class_name Grapple
extends Node2D
## Gancho do astronauta (Godot 4.x). Adicione como filho do Player (nó Node2D
## chamado "Grapple") e, opcionalmente, um Line2D filho para desenhar a corda.
## O Player chama try_attach() e physics_step() (veja o patch no player.gd).

signal attached(point: Node2D)
signal released

@export var grapple_range := 480.0
## O ponto precisa estar pelo menos isto acima do jogador para ser alcançável.
@export var min_height_above := 32.0
## Força do balanço ao segurar esquerda/direita.
@export var swing_force := 900.0
@export var max_swing_speed := 900.0
@export var gravity_scale := 1.0
## Multiplicador de velocidade ao soltar (mantém o momentum).
@export var release_boost := 1.15
@export var rope_line: Line2D

var is_attached := false
var anchor: Node2D
var rope_length := 0.0

var _player: Player
var _highlighted: Node2D


func _ready() -> void:
	_player = get_parent() as Player
	if rope_line:
		rope_line.top_level = true  # pontos da corda em coordenadas globais
		rope_line.visible = false


func _process(_delta: float) -> void:
	if is_attached:
		_update_rope()
	else:
		_update_highlight()


# --- API usada pelo Player --------------------------------------------------

func try_attach() -> bool:
	var target := _find_target()
	if target == null:
		return false
	anchor = target
	rope_length = _player.global_position.distance_to(anchor.global_position)
	is_attached = true
	_set_highlight(null)
	if rope_line:
		rope_line.visible = true
	attached.emit(anchor)
	return true


func release() -> void:
	if not is_attached:
		return
	is_attached = false
	anchor = null
	_player.velocity *= release_boost
	if rope_line:
		rope_line.visible = false
	released.emit()


## Chamado todo frame de física enquanto o gancho está preso.
## dir: -1, 0 ou 1 (esquerda/direita).
func physics_step(delta: float, dir: float) -> void:
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("grapple"):
		release()
		return

	var v := _player.velocity
	v.y += _player.gravity * gravity_scale * delta

	var offset := _player.global_position - anchor.global_position
	var dist := maxf(offset.length(), 0.001)
	var radial := offset / dist  # direção do ponto até o jogador

	# Impulso de balanço na direção tangente à corda.
	if dir != 0.0:
		var tangent := Vector2(-radial.y, radial.x)
		if tangent.x < 0.0:
			tangent = -tangent
		v += tangent * dir * swing_force * delta

	# Corda esticada: remove a velocidade que afastaria o jogador do ponto.
	if dist >= rope_length:
		var outward := v.dot(radial)
		if outward > 0.0:
			v -= radial * outward
		_player.global_position = anchor.global_position + radial * rope_length

	_player.velocity = v.limit_length(max_swing_speed)


# --- Alvo e feedback visual -------------------------------------------------

func _find_target() -> Node2D:
	var best: Node2D = null
	var best_dist := grapple_range
	for node in get_tree().get_nodes_in_group("grapple_point"):
		var point := node as Node2D
		if point == null:
			continue
		var offset := point.global_position - _player.global_position
		if offset.y > -min_height_above:
			continue
		var d := offset.length()
		if d < best_dist:
			best = point
			best_dist = d
	return best


## O ponto alcançável mais próximo brilha: o jogador aprende sem texto.
func _update_highlight() -> void:
	_set_highlight(_find_target())


func _set_highlight(target: Node2D) -> void:
	if target == _highlighted:
		return
	if _highlighted and _highlighted.has_method("set_highlight"):
		_highlighted.set_highlight(false)
	_highlighted = target
	if _highlighted and _highlighted.has_method("set_highlight"):
		_highlighted.set_highlight(true)


func _update_rope() -> void:
	if rope_line == null or anchor == null:
		return
	rope_line.clear_points()
	rope_line.add_point(_player.global_position)
	rope_line.add_point(anchor.global_position)
