class_name BossRoom
extends Area2D
## Sala de chefe estilo Mega Man (Godot 4.x).
## Quando o jogador entra: fecha a(s) porta(s) de entrada, trava a câmera na
## arena, espera um instante e começa a luta. Quando o chefe cai: abre as portas
## e destrava a câmera.
##
## Este Area2D é o gatilho: uma faixa logo DEPOIS da porta de entrada, dentro
## da arena (para a porta não fechar em cima do jogador).
## No chefe: deixe "Auto Start" desligado e "Trigger Area" vazio.
## O jogador precisa ter um Camera2D filho (nome "Camera2D").

signal fight_started
signal fight_ended

@export var boss: Boss
## Cantos da arena (dois Marker2D). Faça o retângulo do tamanho da tela
## (1920×1080) para a câmera ficar fixa, como no Mega Man.
@export var arena_top_left: Marker2D
@export var arena_bottom_right: Marker2D
## Portas que fecham ao começar e abrem ao vencer.
@export var entrance_doors: Array[BossDoor] = []
## Portas que já começam fechadas e abrem só ao vencer.
@export var exit_doors: Array[BossDoor] = []
@export var camera_time := 0.8
## Pausa entre a porta fechar e o chefe começar a atacar.
@export var intro_delay := 1.0
## Pausa entre o chefe cair e as portas abrirem.
@export var victory_delay := 1.5

var _triggered := false
var _camera: Camera2D
var _old_limits := {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if boss:
		boss.defeated.connect(_on_boss_defeated)
	else:
		push_warning("BossRoom: campo Boss vazio.")


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	_camera = body.get_node_or_null("Camera2D") as Camera2D
	_start_fight()


func _start_fight() -> void:
	for door in entrance_doors:
		door.close()
	_set_camera_limits(true)
	await get_tree().create_timer(camera_time + intro_delay).timeout
	fight_started.emit()
	if boss:
		boss.start_fight()


func _on_boss_defeated() -> void:
	await get_tree().create_timer(victory_delay).timeout
	for door in entrance_doors + exit_doors:
		door.open()
	_set_camera_limits(false)
	fight_ended.emit()


func _set_camera_limits(lock: bool) -> void:
	if _camera == null or arena_top_left == null or arena_bottom_right == null:
		push_warning("BossRoom: câmera ou cantos da arena não encontrados.")
		return
	var target := {}
	if lock:
		_old_limits = {
			"limit_left": _camera.limit_left,
			"limit_top": _camera.limit_top,
			"limit_right": _camera.limit_right,
			"limit_bottom": _camera.limit_bottom,
		}
		# Primeiro prende a câmera onde ela está, depois desliza até a arena.
		var half := get_viewport_rect().size / (2.0 * _camera.zoom)
		var center := _camera.get_screen_center_position()
		_camera.limit_left = int(center.x - half.x)
		_camera.limit_top = int(center.y - half.y)
		_camera.limit_right = int(center.x + half.x)
		_camera.limit_bottom = int(center.y + half.y)
		target = {
			"limit_left": int(arena_top_left.global_position.x),
			"limit_top": int(arena_top_left.global_position.y),
			"limit_right": int(arena_bottom_right.global_position.x),
			"limit_bottom": int(arena_bottom_right.global_position.y),
		}
	else:
		target = _old_limits
	var tween := create_tween().set_parallel(true)
	for property in target:
		tween.tween_property(_camera, property, target[property], camera_time)
