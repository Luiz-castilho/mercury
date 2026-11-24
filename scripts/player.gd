class_name Player
extends CharacterBody2D
## Astronauta (Godot 4.x). Anexe a um CharacterBody2D.
## Estrutura esperada de filhos:
##   CollisionShape2D, Sprite2D (opcional),
##   AttackArea (Area2D + CollisionShape2D, à direita do jogador),
##   DownAttackArea (Area2D + CollisionShape2D, embaixo do jogador).
## Arraste AttackArea e DownAttackArea para os campos do Inspetor.

signal died
signal health_changed(current: int, maximum: int)

@export_group("Movimento")
@export var speed := 450.0
@export var acceleration := 3100.0
@export var friction := 3500.0
@export_range(0.0, 1.0) var air_control := 0.8

@export_group("Gravidade e pulo")
## Gravidade baixa (Mercúrio ~40% da padrão de 980). Troque por planeta.
@export var gravity := 420.0
@export var max_fall_speed := 600.0
@export var jump_velocity := -440.0
## Soltar o botão cedo corta o pulo (pulo variável).
@export_range(0.0, 1.0) var jump_cut_multiplier := 0.5
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.10
## Pulo duplo: só funciona depois de pegar a melhoria "double_jump" no mapa
## (ou marcando "always_double_jump" para testar).
@export var double_jump_velocity := -400.0
@export var always_double_jump := false

@export_group("Wall jump")
## Estilo Transformice: encostado na parede, vire para o lado CONTRÁRIO e pule.
## O jogador é lançado para longe da parede; para continuar subindo, vire de
## volta para a parede (ou para a parede da frente) e repita.
@export var wall_jump_enabled := true
@export var wall_jump_velocity := -420.0
## Empurrão horizontal para longe da parede.
@export var wall_jump_push := 330.0
## Velocidade máxima de queda enquanto desliza encostado na parede.
@export var wall_slide_speed := 140.0
## Tempo de tolerância depois de soltar a parede em que o pulo ainda vale
## (dá tempo de virar para o outro lado e apertar pulo).
@export var wall_coyote_time := 0.18

@export_group("Dash")
@export var dash_speed := 900.0
@export var dash_duration := 0.18
@export var dash_cooldown := 0.5

@export_group("Ataque")
@export var attack_damage := 1
@export var attack_duration := 0.18
@export var attack_cooldown := 0.30
## Impulso ao acertar o ataque para baixo (quicar).
@export var pogo_velocity := -430.0
@export_group("Gancho: inclinação")
## Quanto o corpo pode inclinar acompanhando a corda (graus).
@export var tilt_max_deg := 80.0
## Velocidade com que o corpo acompanha a corda.
@export var tilt_speed := 14.0
@export_group("")
@export var attack_area: Area2D
@export var down_attack_area: Area2D

@export_group("Vida")
@export var max_health := 5
@export var invulnerability_time := 1.0
@export var knockback := Vector2(250.0, -250.0)
## Se cair abaixo desta altura, o jogador morre.
@export var fall_death_y := 4000.0
## true: cair no vão volta ao último chão seguro, sem dano. false: morre.
@export var fall_returns_to_safe := true

const DEFAULT_KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"dash": [KEY_SHIFT, KEY_L],
	"attack": [KEY_J, KEY_X],
	"grapple": [KEY_K, KEY_E],
}

var health := 5
var facing := 1

var _coyote := 0.0
var _jump_buffer := 0.0
var _dash_timer := 0.0
var _dash_cd := 0.0
var _can_air_dash := true
var _air_jumps_max := 0
var _air_jumps_left := 0
var _wall_normal_x := 0.0   # lado da última parede tocada (+1 parede à esquerda, -1 à direita)
var _wall_coyote := 0.0
var _wall_sliding := false
var _attack_timer := 0.0
var _attack_cd := 0.0
var _down_attack := false
var _hit_this_attack: Array = []
var _invuln := 0.0
var _knockback_timer := 0.0
var _dead := false
var last_safe_position := Vector2.ZERO
var _was_on_floor := true
var _sprite_rest := Vector2.ZERO
var _tilt_pivot := Vector2.ZERO
var _land_timer := 0.0
## Vento atual (soma de todas as WindZone em que o jogador está).
var wind := Vector2.ZERO
var _wind_sources := {}

@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var _grapple: Grapple = get_node_or_null("Grapple")


func _ready() -> void:
	_ensure_input_actions()
	if _sprite:
		_sprite_rest = _sprite.position
		var body_shape := get_node_or_null("CollisionShape2D") as Node2D
		_tilt_pivot = body_shape.position if body_shape else _sprite_rest
	add_to_group("player")
	call_deferred("_reset_safe_position")  # depois que a fase posiciona o jogador
	health = max_health
	health_changed.emit(health, max_health)
	_set_area(attack_area, false)
	_set_area(down_attack_area, false)
	if _grapple:
		_grapple.released.connect(func():
			_can_air_dash = true
			_air_jumps_left = _air_jumps_max)
	refresh_upgrades()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if global_position.y > fall_death_y:
		if fall_returns_to_safe:
			return_to_safe_position()
		else:
			_die()
		return

	_tick_timers(delta)
	var dir := Input.get_axis("move_left", "move_right")

	if dir != 0.0 and _dash_timer <= 0.0 and _attack_timer <= 0.0:
		facing = 1 if dir > 0.0 else -1
		if _sprite:
			_sprite.flip_h = facing < 0

	if _grapple:
		if Input.is_action_just_pressed("grapple") and not _grapple.is_attached:
			_grapple.try_attach()
		if _grapple.is_attached:
			_dash_timer = 0.0
			_grapple.physics_step(delta, dir)
			move_and_slide()
			_update_animation(delta)
			return

	_handle_dash_input()
	if _dash_timer > 0.0:
		velocity = Vector2(facing * dash_speed, 0.0)
	else:
		_apply_gravity(delta)
		_handle_horizontal(dir, delta)
		_handle_jump()

	_handle_attack_input()
	_update_attack()
	move_and_slide()
	_update_animation(delta)


# --- Animação ---------------------------------------------------------------

## Escolhe a animação pelo estado atual. Nomes no SpriteFrames do AnimatedSprite2D:
## idle, run, jump, fall, land, dash, attack, attack_down, grapple, hurt, dead.
func _update_animation(delta: float) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_land_timer = 0.14
	_was_on_floor = on_floor
	_land_timer = maxf(_land_timer - delta, 0.0)

	var anim := "idle"
	if _knockback_timer > 0.0:
		anim = "hurt"
	elif _grapple and _grapple.is_attached:
		anim = "grapple"
	elif _dash_timer > 0.0:
		anim = "dash"
	elif _attack_timer > 0.0:
		anim = "attack_down" if _down_attack else "attack"
	elif _wall_sliding:
		anim = "wall_slide" if _sprite.sprite_frames.has_animation("wall_slide") else "fall"
	elif not on_floor:
		anim = "jump" if velocity.y < 0.0 else "fall"
	elif _land_timer > 0.0:
		anim = "land"
	elif absf(velocity.x) > 30.0:
		anim = "run"
	_play_anim(anim)
	_update_tilt(delta)
	# Pisca enquanto está invulnerável depois de levar dano.
	_sprite.modulate.a = 0.45 if _invuln > 0.0 and fmod(_invuln, 0.2) < 0.1 else 1.0


## Com o gancho preso, o corpo gira em torno do centro para ficar alinhado com a
## corda (cabeça para o ponto de ancoragem). Solto, volta à posição normal.
func _update_tilt(delta: float) -> void:
	if _sprite == null:
		return
	var target := 0.0
	if _grapple and _grapple.is_attached:
		var dir := _grapple.rope_direction()
		if dir != Vector2.ZERO:
			var limit := deg_to_rad(tilt_max_deg)
			target = clampf(wrapf(dir.angle() + PI / 2.0, -PI, PI), -limit, limit)
	_sprite.rotation = lerp_angle(_sprite.rotation, target, 1.0 - exp(-tilt_speed * delta))
	# Gira em torno do centro do corpo, não do centro da imagem.
	_sprite.position = _tilt_pivot + (_sprite_rest - _tilt_pivot).rotated(_sprite.rotation)


func _play_anim(anim: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _sprite.sprite_frames.has_animation(anim) and _sprite.animation != anim:
		_sprite.play(anim)


# --- Movimento --------------------------------------------------------------

func _tick_timers(delta: float) -> void:
	if is_on_floor():
		_coyote = coyote_time
		_can_air_dash = true
		_air_jumps_left = _air_jumps_max
		last_safe_position = global_position
	else:
		_coyote -= delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer -= delta

	_update_wall_contact(delta)
	_dash_timer -= delta
	_dash_cd -= delta
	_attack_cd -= delta
	_knockback_timer -= delta

	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_set_area(attack_area, false)
			_set_area(down_attack_area, false)

	# O piscar da invulnerabilidade fica em _update_animation (só no sprite).
	if _invuln > 0.0:
		_invuln -= delta


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var limit := wall_slide_speed if _wall_sliding else max_fall_speed
		velocity.y = minf(velocity.y + gravity * delta, limit)


func _handle_horizontal(dir: float, delta: float) -> void:
	if _knockback_timer > 0.0:
		return
	var control := 1.0 if is_on_floor() else air_control
	# O vento desloca a velocidade-alvo: contra o vento você anda mais devagar,
	# a favor anda mais rápido, e parado é empurrado. O dash ignora o vento.
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * speed + wind.x, acceleration * control * delta)
	else:
		velocity.x = move_toward(velocity.x, wind.x, friction * control * delta)


## Chamado pelas WindZone. force = Vector2.ZERO remove a contribuição da zona.
func set_wind(source: Object, force: Vector2) -> void:
	if force == Vector2.ZERO:
		_wind_sources.erase(source)
	else:
		_wind_sources[source] = force
	wind = Vector2.ZERO
	for f in _wind_sources.values():
		wind += f


func _handle_jump() -> void:
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
	elif Input.is_action_just_pressed("jump") and _can_wall_jump():
		_do_wall_jump()
	elif Input.is_action_just_pressed("jump") and _air_jumps_left > 0 and not is_on_floor():
		_air_jumps_left -= 1
		velocity.y = double_jump_velocity
		_jump_buffer = 0.0
		_spawn_double_jump_effect()
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and _dash_timer <= 0.0:
		if is_on_floor() or _can_air_dash:
			_dash_timer = dash_duration
			_dash_cd = dash_cooldown
			if not is_on_floor():
				_can_air_dash = false


# --- Wall jump --------------------------------------------------------------

func _update_wall_contact(delta: float) -> void:
	_wall_sliding = false
	if not wall_jump_enabled or is_on_floor():
		_wall_coyote = 0.0
		return
	if is_on_wall():
		var n := get_wall_normal().x
		if absf(n) > 0.7:
			_wall_normal_x = signf(n)
			_wall_coyote = wall_coyote_time
			# Só desliza devagar se estiver caindo e empurrando contra a parede.
			var dir := Input.get_axis("move_left", "move_right")
			_wall_sliding = velocity.y > 0.0 and dir * _wall_normal_x < 0.0
			return
	_wall_coyote -= delta


## Só pula se estiver (ou acabou de estar) na parede e virado para o lado
## contrário a ela — o "virar e pular" do Transformice.
func _can_wall_jump() -> bool:
	if not wall_jump_enabled or is_on_floor() or _wall_coyote <= 0.0:
		return false
	return facing == int(_wall_normal_x)


func _do_wall_jump() -> void:
	velocity = Vector2(_wall_normal_x * wall_jump_push, wall_jump_velocity)
	_wall_coyote = 0.0
	_wall_sliding = false
	_jump_buffer = 0.0
	_can_air_dash = true


## Lê do SceneManager quais melhorias o jogador já tem.
func refresh_upgrades() -> void:
	var manager := get_node_or_null("/root/SceneManager")
	var has_double: bool = always_double_jump or (manager != null and manager.has_upgrade("double_jump"))
	_air_jumps_max = 1 if has_double else 0
	_air_jumps_left = _air_jumps_max


## Anel de poeira nos pés no pulo duplo (feito por código, sem arte).
func _spawn_double_jump_effect() -> void:
	var body := get_node_or_null("CollisionShape2D") as Node2D
	var feet := global_position + (body.position if body else Vector2.ZERO) + Vector2(0, 40)
	var ring := CPUParticles2D.new()
	ring.one_shot = true
	ring.explosiveness = 1.0
	ring.amount = 18
	ring.lifetime = 0.35
	ring.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	ring.emission_sphere_radius = 6.0
	ring.direction = Vector2.DOWN
	ring.spread = 80.0
	ring.gravity = Vector2.ZERO
	ring.initial_velocity_min = 120.0
	ring.initial_velocity_max = 200.0
	ring.scale_amount_min = 2.0
	ring.scale_amount_max = 4.0
	ring.color = Color(0.75, 0.92, 1.0, 0.9)
	get_parent().add_child(ring)
	ring.global_position = feet
	ring.emitting = true
	ring.finished.connect(ring.queue_free)


# --- Ataque -----------------------------------------------------------------

func _handle_attack_input() -> void:
	if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0 and _attack_timer <= 0.0:
		_down_attack = not is_on_floor() and Input.is_action_pressed("move_down")
		_attack_timer = attack_duration
		_attack_cd = attack_cooldown
		_hit_this_attack.clear()
		_set_area(down_attack_area if _down_attack else attack_area, true)


func _update_attack() -> void:
	if _attack_timer <= 0.0:
		return
	var area := down_attack_area if _down_attack else attack_area
	if area == null:
		return
	if not _down_attack:
		area.scale.x = facing  # espelha o ataque lateral
	for body in area.get_overlapping_bodies():
		_try_hit(body)
	for other in area.get_overlapping_areas():
		_try_hit(other)


func _try_hit(target: Node) -> void:
	if target == self or _hit_this_attack.has(target):
		return
	var hit := false
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, global_position)
		hit = true
	elif target.is_in_group("bounce"):  # ex.: cristal de impulso
		hit = true
		if target.has_method("on_bounced"):
			target.on_bounced()
	if not hit:
		return
	_hit_this_attack.append(target)
	if _down_attack:
		var strength = target.get("bounce_velocity")  # cristais têm impulso próprio
		velocity.y = strength if strength != null else pogo_velocity
		_can_air_dash = true
		_air_jumps_left = _air_jumps_max


func _set_area(area: Area2D, enabled: bool) -> void:
	if area:
		area.monitoring = enabled


# --- Vida -------------------------------------------------------------------

## Chamado por inimigos, espinhos e chefe: player.take_damage(1, global_position)
func take_damage(amount: int, from_position := Vector2.ZERO) -> void:
	if _dead or _invuln > 0.0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		_die()
		return
	_invuln = invulnerability_time
	_knockback_timer = 0.2
	_dash_timer = 0.0
	var push := signf(global_position.x - from_position.x)
	if push == 0.0:
		push = -facing
	velocity = Vector2(knockback.x * push, knockback.y)


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


## Volta ao último chão seguro (usado por espinhos e quedas em vãos).
func return_to_safe_position() -> void:
	if _grapple and _grapple.is_attached:
		_grapple.release()
	global_position = last_safe_position
	velocity = Vector2.ZERO
	_dash_timer = 0.0


func _reset_safe_position() -> void:
	last_safe_position = global_position


func _die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector2.ZERO
	if _sprite:
		_sprite.rotation = 0.0
		_sprite.position = _sprite_rest
	_play_anim("dead")
	await get_tree().create_timer(0.6).timeout
	died.emit()


# --- Controles padrão (podem ser trocados em Mapa de Entrada) ----------------

func _ensure_input_actions() -> void:
	for action in DEFAULT_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in DEFAULT_KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
