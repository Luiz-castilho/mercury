extends Area2D
## Cristal de impulso (Godot 4.x). Use a cena bounce_crystal.tscn.
## Ao receber o ataque para baixo do jogador, ele impulsiona o jogador para cima
## (e devolve o dash aéreo). Reutilizável: arraste a cena quantas vezes quiser.
## A DownAttackArea do jogador precisa ter na máscara a camada deste cristal (32).

## Velocidade vertical dada ao jogador (negativo = para cima). Mais forte que o
## golpe normal para baixo (-430), por isso o cristal serve para alcançar lugares altos.
@export var bounce_velocity := -700.0
## Nó visual (pode ser o Visual, que agrupa a arte). Treme ao ser usado.
@export var sprite: CanvasItem
## Tempo apagado depois de usado (0 = reutilizável na hora).
@export var recharge_time := 0.0

var _ready_to_bounce := true


func _ready() -> void:
	add_to_group("bounce")


## Chamado pelo player.gd quando o ataque acerta.
func on_bounced() -> void:
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.25, 0.8), 0.06)
		tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)
	if recharge_time > 0.0:
		_recharge()


func _recharge() -> void:
	set_deferred("monitorable", false)
	if sprite:
		sprite.modulate.a = 0.3
	await get_tree().create_timer(recharge_time).timeout
	set_deferred("monitorable", true)
	if sprite:
		sprite.modulate.a = 1.0
