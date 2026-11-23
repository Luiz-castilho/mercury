class_name RoboMinerador
extends CharacterBody2D
## Robô minerador (Godot 4.x): persegue em velocidade moderada e só ataca de
## muito perto, com a broca. Depois do golpe fica vulnerável por um tempo;
## fora dessa janela a armadura bloqueia o dano.
##
## Estrutura de nós (script no nó raiz):
##   RoboMinerador (CharacterBody2D)
##   ├── CollisionShape2D
##   ├── Sprite2D                      -> campo "sprite" (arte virada para a DIREITA)
##   ├── DetectionArea (Area2D)        -> raio médio; máscara = camada do jogador
##   ├── FloorCheck (RayCast2D, opcional) -> aponta para baixo, à frente do robô
##   └── DrillPivot (Node2D)           -> campo "drill_pivot"
##       ├── Telegraph (Polygon2D ou ColorRect semitransparente) -> "telegraph"
##       └── DrillHitbox (Area2D + CollisionShape2D, mesma área do Telegraph) -> "drill_hitbox"

signal died

enum State { IDLE, CHASE, WINDUP, ATTACK, VULNERABLE, DEAD }

@export_group("Vida e dano")
@export var max_health := 3
@export var drill_damage := 1
## true: só leva dano na janela de vulnerabilidade (depois do golpe).
@export var armored_outside_window := true

@export_group("Movimento")
@export var gravity := 420.0
@export var patrol_speed := 40.0
@export var chase_speed := 150.0
## Distância horizontal para iniciar o ataque (precisa estar bem perto).
@export var attack_range := 80.0

@export_group("Ataque (segundos)")
@export var windup_time := 0.5
@export var attack_time := 0.25
## Janela em que o robô pode ser atingido após o golpe.
@export var vulnerable_time := 1.3

@export_group("Visual")
@export var vulnerable_tint := Color(1.0, 0.75, 0.5)

@export_group("Nós")
@export var detection_area: Area2D
@export var drill_pivot: Node2D
@export var telegraph: CanvasItem
@export var drill_hitbox: Area2D
@export var sprite: Node2D
@export var floor_check: RayCast2D

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
		State.CHASE:
			_process_chase()
		State.WINDUP:
			velocity.x = 0.0
			if _timer >= windup_time:
				_enter(State.ATTACK)
		State.ATTACK:
			velocity.x = 0.0
			_check_drill_hit()
			if _timer >= attack_time:
				_enter(State.VULNERABLE)
		State.VULNERABLE:
			velocity.x = 0.0
			if _timer >= vulnerable_time:
				_enter(State.CHASE if _find_player_in_range() else State.IDLE)

	move_and_slide()


func _enter(new_state: State) -> void:
	_state = new_state
	_timer = 0.0
	if telegraph:
		telegraph.visible = new_state == State.WINDUP
	if drill_hitbox:
		drill_hitbox.monitoring = new_state == State.ATTACK
	if new_state == State.ATTACK:
		_hit_player = false
	if sprite:
		sprite.modulate = vulnerable_tint if new_state == State.VULNERABLE else Color.WHITE


func _process_idle() -> void:
	if _find_player_in_range():
		_enter(State.CHASE)
		return
	if is_on_wall() or _ledge_ahead():
		_face(-facing)
	velocity.x = facing * patrol_speed


func _process_chase() -> void:
	if not _find_player_in_range():
		_enter(State.IDLE)
		return
	var dx := _player.global_position.x - global_position.x
	_face(1 if dx > 0.0 else -1)
	var dy := absf(_player.global_position.y - global_position.y)
	if absf(dx) <= attack_range and dy < 80.0:
		velocity.x = 0.0
		_enter(State.WINDUP)
		return
	velocity.x = 0.0 if _ledge_ahead() else facing * chase_speed


func _ledge_ahead() -> bool:
	if floor_check == null or not is_on_floor():
		return false
	floor_check.position.x = absf(floor_check.position.x) * facing
	floor_check.force_raycast_update()
	return not floor_check.is_colliding()


func _find_player_in_range() -> bool:
	if detection_area == null:
		return false
	for body in detection_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			_player = body
			return true
	return false


func _check_drill_hit() -> void:
	if _hit_player or drill_hitbox == null:
		return
	for body in drill_hitbox.get_overlapping_bodies():
		if body.is_in_group("player"):
			body.take_damage(drill_damage, global_position)
			_hit_player = true


func _face(dir: int) -> void:
	facing = dir
	if drill_pivot:
		drill_pivot.scale.x = facing
	if sprite:
		sprite.scale.x = absf(sprite.scale.x) * facing


# --- Dano -------------------------------------------------------------------

## O jogador chama isto ao atacar.
func take_damage(amount: int, _from_position := Vector2.ZERO) -> void:
	if _state == State.DEAD:
		return
	if armored_outside_window and _state != State.VULNERABLE:
		_deflect()
		return
	health -= amount
	_flash()
	if health <= 0:
		_die()


func _deflect() -> void:
	modulate = Color(0.7, 0.85, 1.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.12)


func _flash() -> void:
	modulate = Color(1.8, 1.8, 1.8)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)


func _die() -> void:
	_state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if telegraph:
		telegraph.visible = false
	if drill_hitbox:
		drill_hitbox.set_deferred("monitoring", false)
	died.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()
