class_name Lampesouro
extends CharacterBody2D
## Lampesouro (Godot 4.x): besouro que carrega um cristal prisma.
## Só ataca se o jogador estiver muito perto: alerta, carga lenta com aviso
## visual da área do laser, disparo e recarga.
##
## Estrutura de nós (script no nó raiz):
##   Lampesouro (CharacterBody2D)
##   ├── CollisionShape2D
##   ├── AnimatedSprite2D              -> campo "sprite" (arte virada para a DIREITA)
##   │     animações: idle, walk, alert, charge, fire, cooldown, dead
##   ├── DetectionArea (Area2D)        -> raio curto; máscara = camada do jogador
##   └── LaserPivot (Node2D)           -> campo "laser_pivot"
##       ├── Telegraph (Polygon2D ou ColorRect semitransparente) -> "telegraph"
##       └── LaserHitbox (Area2D + CollisionShape2D, mesma área do Telegraph) -> "laser_hitbox"
## Coloque o LaserPivot/Telegraph/LaserHitbox À DIREITA do besouro; o script espelha.

signal died

enum State { IDLE, ALERT, CHARGE, FIRE, COOLDOWN, DEAD }

@export_group("Vida e dano")
@export var max_health := 2
@export var laser_damage := 1

@export_group("Movimento")
@export var gravity := 420.0
## 0 = fica parado até o jogador chegar perto.
@export var patrol_speed := 30.0

@export_group("Ataque (segundos)")
@export var alert_time := 0.35
## Tempo do aviso visual: quanto maior, mais fácil.
@export var charge_time := 1.2
@export var fire_time := 0.3
@export var cooldown_time := 1.8

@export_group("Nós")
@export var detection_area: Area2D
@export var laser_pivot: Node2D
@export var telegraph: CanvasItem
@export var laser_hitbox: Area2D
@export var sprite: AnimatedSprite2D

var health := 0
var facing := 1

var _state := State.IDLE
var _timer := 0.0
var _hit_player := false
var _player: Node2D


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	_face(-1)
	_enter(State.IDLE)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	_timer += delta

	match _state:
		State.IDLE:
			_process_idle()
		State.ALERT:
			velocity.x = 0.0
			if _timer >= alert_time:
				_enter(State.CHARGE)
		State.CHARGE:
			velocity.x = 0.0
			if _timer >= charge_time:
				_enter(State.FIRE)
		State.FIRE:
			velocity.x = 0.0
			_check_laser_hit()
			if _timer >= fire_time:
				_enter(State.COOLDOWN)
		State.COOLDOWN:
			velocity.x = 0.0
			if _timer >= cooldown_time:
				_enter(State.IDLE)
	move_and_slide()


func _enter(new_state: State) -> void:
	_state = new_state
	_timer = 0.0
	if telegraph:
		telegraph.visible = new_state == State.CHARGE
	if laser_hitbox:
		laser_hitbox.monitoring = new_state == State.FIRE
	if new_state == State.FIRE:
		_hit_player = false
	if new_state == State.ALERT:
		_face_player()
	match new_state:
		State.IDLE: _play(&"idle", true)
		State.ALERT: _play(&"alert", true)
		State.CHARGE: _play(&"charge", true)
		State.FIRE: _play(&"fire", true)
		State.COOLDOWN: _play(&"cooldown", true)


func _process_idle() -> void:
	if _find_player_in_range():
		_enter(State.ALERT)
		return
	if patrol_speed > 0.0:
		if is_on_wall():
			_face(-facing)
		velocity.x = facing * patrol_speed
		_play(&"walk")
	else:
		velocity.x = 0.0
		_play(&"idle")


## Troca a animação. restart = true reinicia mesmo se já for a atual.
func _play(anim: StringName, restart := false) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim):
		return
	if restart or sprite.animation != anim:
		sprite.play(anim)


func _find_player_in_range() -> bool:
	if detection_area == null:
		return false
	for body in detection_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			_player = body
			return true
	return false


func _check_laser_hit() -> void:
	if _hit_player or laser_hitbox == null:
		return
	for body in laser_hitbox.get_overlapping_bodies():
		if body.is_in_group("player"):
			body.take_damage(laser_damage, global_position)
			_hit_player = true


func _face_player() -> void:
	if is_instance_valid(_player):
		_face(1 if _player.global_position.x > global_position.x else -1)


func _face(dir: int) -> void:
	facing = dir
	if laser_pivot:
		laser_pivot.scale.x = facing
	if sprite:
		sprite.scale.x = absf(sprite.scale.x) * facing


# --- Dano -------------------------------------------------------------------

## O jogador chama isto ao atacar.
func take_damage(amount: int, _from_position := Vector2.ZERO) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	_flash()
	if health <= 0:
		_die()


func _flash() -> void:
	modulate = Color(1.8, 1.8, 1.8)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)


func _die() -> void:
	_state = State.DEAD
	_play(&"dead", true)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if telegraph:
		telegraph.visible = false
	if laser_hitbox:
		laser_hitbox.set_deferred("monitoring", false)
	died.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()
