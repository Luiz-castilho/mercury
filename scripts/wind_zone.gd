class_name WindZone
extends Area2D
## Zona de vento forte de Mercúrio (Godot 4.x). Estrutura:
##   WindZone (Area2D)  <- este script
##   └── CollisionShape2D com RectangleShape2D (a área onde venta)
## Máscara de colisão na camada do jogador (1). O jogador precisa ter set_wind()
## (player.gd já tem).
##
## Ciclo das rajadas: CALMARIA -> AVISO (a poeira começa a correr) -> RAJADA -> ...
## Durante a rajada o jogador é empurrado na "direction". O dash atravessa o vento.

signal gust_warning
signal gust_started
signal gust_ended

enum Phase { CALM, WARNING, GUST }

## Para onde o vento sopra. LEFT = contra quem avança para a direita.
@export var direction := Vector2.LEFT
## Velocidade que o vento soma/subtrai do jogador (a corrida dele é 450).
@export var strength := 160.0
@export var calm_time := 2.2
@export var warning_time := 0.7
@export var gust_time := 1.6
## Quanto tempo o vento leva para chegar à força total (e para parar).
@export var ramp_time := 0.25
## true: vento constante, sem rajadas.
@export var always_on := false
@export var show_dust := true
@export var dust_color := Color(0.82, 0.82, 0.88, 0.85)

var phase := Phase.CALM

var _timer := 0.0
var _power := 0.0  # 0..1
var _bodies: Array[Node2D] = []
var _dust: CPUParticles2D


func _ready() -> void:
	collision_layer = 0
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_timer = calm_time
	if show_dust:
		_build_dust()


func is_gusting() -> bool:
	return always_on or phase == Phase.GUST


func is_warning() -> bool:
	return phase == Phase.WARNING


func _physics_process(delta: float) -> void:
	if not always_on:
		_timer -= delta
		if _timer <= 0.0:
			_advance_phase()

	var target := 1.0 if is_gusting() else 0.0
	_power = move_toward(_power, target, delta / maxf(ramp_time, 0.01))

	var force := direction.normalized() * strength * _power
	for body in _bodies:
		if is_instance_valid(body):
			body.set_wind(self, force)
	_update_dust(delta)


func _advance_phase() -> void:
	match phase:
		Phase.CALM:
			phase = Phase.WARNING
			_timer = warning_time
			gust_warning.emit()
		Phase.WARNING:
			phase = Phase.GUST
			_timer = gust_time
			gust_started.emit()
		Phase.GUST:
			phase = Phase.CALM
			_timer = calm_time
			gust_ended.emit()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_wind") and not _bodies.has(body):
		_bodies.append(body)


func _on_body_exited(body: Node2D) -> void:
	if _bodies.has(body):
		_bodies.erase(body)
		body.set_wind(self, Vector2.ZERO)


func _exit_tree() -> void:
	for body in _bodies:
		if is_instance_valid(body):
			body.set_wind(self, Vector2.ZERO)
	_bodies.clear()


# --- Poeira (visual do vento, sem precisar de arte) -------------------------

func _zone_rect() -> Rect2:
	for child in get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var size: Vector2 = child.shape.size
			return Rect2(child.position - size / 2.0, size)
	return Rect2(-200, -100, 400, 200)


func _build_dust() -> void:
	var rect := _zone_rect()
	_dust = CPUParticles2D.new()
	_dust.amount = 120
	_dust.lifetime = 1.4
	_dust.preprocess = 1.4
	_dust.local_coords = false
	_dust.position = rect.get_center()
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = rect.size / 2.0
	_dust.direction = direction.normalized()
	_dust.spread = 4.0
	_dust.gravity = Vector2.ZERO
	_dust.initial_velocity_min = 60.0
	_dust.initial_velocity_max = 90.0
	# Riscos de poeira alinhados com o movimento (não parecem estrelas).
	var streak_grad := Gradient.new()
	streak_grad.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	streak_grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 1)])
	var streak := GradientTexture2D.new()
	streak.gradient = streak_grad
	streak.width = 3
	streak.height = 26
	streak.fill_from = Vector2(0.5, 1.0)
	streak.fill_to = Vector2(0.5, 0.0)
	_dust.texture = streak
	_dust.particle_flag_align_y = true
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.3
	_dust.color = dust_color
	_dust.modulate.a = 0.25
	# Some suavemente no fim da vida.
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_dust.color_ramp = fade
	add_child(_dust)


func _update_dust(delta: float) -> void:
	if _dust == null:
		return
	# Calmaria: pouca poeira lenta. Aviso: começa a acelerar. Rajada: forte.
	var level := _power
	if phase == Phase.WARNING:
		level = maxf(level, 0.35)
	var alpha := lerpf(0.2, 1.0, level)
	_dust.modulate.a = move_toward(_dust.modulate.a, alpha, delta * 3.0)
	_dust.initial_velocity_min = lerpf(60.0, 520.0, level)
	_dust.initial_velocity_max = lerpf(90.0, 700.0, level)
