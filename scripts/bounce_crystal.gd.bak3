extends Area2D
## Cristal de impulso (Godot 4.x). Area2D com CollisionShape2D e Sprite2D.
## Ao receber o ataque para baixo do jogador, ele quica. Reutilizável.
## A DownAttackArea do jogador precisa ter na máscara a camada deste cristal.

@export var sprite: CanvasItem


func _ready() -> void:
	add_to_group("bounce")


## Chamado pelo player.gd quando o ataque para baixo acerta.
func on_bounced() -> void:
	if sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.25, 0.8), 0.06)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)
