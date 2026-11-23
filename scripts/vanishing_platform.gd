extends StaticBody2D
## Plataforma que some (Godot 4.x). Estrutura:
##   VanishingPlatform (StaticBody2D)  <- este script
##   ├── CollisionShape2D   (arraste para "collision")
##   ├── Sprite2D           (arraste para "sprite")
##   └── Trigger (Area2D + CollisionShape2D fino logo ACIMA da plataforma)
## O Trigger deve ter máscara de colisão na camada do jogador.

@export var trigger: Area2D
@export var collision: CollisionShape2D
@export var sprite: Node2D
## Tempo de tremor antes de sumir (o aviso visual).
@export var shake_time := 0.5
@export var shake_amount := 3.0
## Tempo sumida. Curto para nunca travar a progressão.
@export var hidden_time := 3.0
@export_range(0.0, 1.0) var ghost_alpha := 0.25

var _busy := false


func _ready() -> void:
	trigger.body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node2D) -> void:
	if _busy or not body.is_in_group("player"):
		return
	_busy = true
	_vanish_cycle()


func _vanish_cycle() -> void:
	# 1. Treme (aviso).
	var origin := sprite.position
	var elapsed := 0.0
	while elapsed < shake_time:
		sprite.position = origin + Vector2(randf_range(-shake_amount, shake_amount), 0.0)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	sprite.position = origin

	# 2. Some: o contorno fantasma mostra onde ela volta.
	collision.set_deferred("disabled", true)
	sprite.modulate.a = ghost_alpha
	await get_tree().create_timer(hidden_time).timeout

	# 3. Volta.
	collision.set_deferred("disabled", false)
	sprite.modulate.a = 1.0
	_busy = false
