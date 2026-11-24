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

@export_group("Fundo da arena")
## Imagem de fundo que aparece quando a luta começa e fica enquanto o jogador
## estiver dentro da arena. Se ele morrer, a fase recarrega no checkpoint e o
## fundo some sozinho (só volta quando entrar na sala de novo).
@export var arena_background: Texture2D
@export var background_fade_time := 0.6
## Ordem de desenho: atrás dos tiles e personagens (0), na frente do céu.
@export var background_z_index := -10

var _triggered := false
var _camera: Camera2D
var _old_limits := {}
var _background: Sprite2D
var _bg_visible := false
var _player: Node2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Se os campos de portas estiverem vazios, usa os grupos das portas.
	if entrance_doors.is_empty():
		_collect_doors("boss_entrance_door", entrance_doors)
	if exit_doors.is_empty():
		_collect_doors("boss_exit_door", exit_doors)
	if boss:
		boss.defeated.connect(_on_boss_defeated)
	else:
		push_warning("BossRoom: campo Boss vazio.")


func _collect_doors(group_name: String, target: Array[BossDoor]) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if node is BossDoor:
			target.append(node)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	_player = body
	_camera = body.get_node_or_null("Camera2D") as Camera2D
	_start_fight()


func _start_fight() -> void:
	_build_background()
	_set_background_visible(true)
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


# --- Fundo da arena ----------------------------------------------------------

func _process(_delta: float) -> void:
	# Depois da luta: o fundo fica enquanto o jogador está na arena e some quando ele sai.
	if _background == null or _player == null or not is_instance_valid(_player):
		return
	_set_background_visible(_arena_rect().has_point(_player.global_position))


func _arena_rect() -> Rect2:
	if arena_top_left == null or arena_bottom_right == null:
		return Rect2()
	var a := arena_top_left.global_position
	return Rect2(a, arena_bottom_right.global_position - a)


## Cria o Sprite2D do fundo cobrindo a arena inteira (corta as sobras, sem distorcer).
func _build_background() -> void:
	if arena_background == null or _background != null:
		return
	var rect := _arena_rect()
	if rect.size == Vector2.ZERO:
		push_warning("BossRoom: defina arena_top_left/arena_bottom_right para o fundo.")
		return
	_background = Sprite2D.new()
	_background.texture = arena_background
	_background.centered = true
	_background.z_index = background_z_index
	_background.z_as_relative = false
	var tex_size := arena_background.get_size()
	var cover := maxf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
	_background.scale = Vector2(cover, cover)
	_background.modulate.a = 0.0
	get_parent().add_child(_background)
	_background.global_position = rect.get_center()


func _set_background_visible(on: bool) -> void:
	if _background == null or on == _bg_visible:
		return
	_bg_visible = on
	create_tween().tween_property(_background, "modulate:a", 1.0 if on else 0.0, background_fade_time)


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
