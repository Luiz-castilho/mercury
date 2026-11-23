extends StaticBody2D
## Barreira destrutível com rachadura (Godot 4.x). Estrutura:
##   BreakableWall (StaticBody2D)  <- este script
##   ├── CollisionShape2D (arraste para "collision")
##   └── Sprite2D com a textura rachada (arraste para "sprite")
## A AttackArea do jogador precisa ter na máscara a camada desta barreira.

signal destroyed

@export var health := 1
@export var collision: CollisionShape2D
@export var sprite: CanvasItem


## O jogador chama isto ao atacar (mesmo método usado pelos inimigos).
func take_damage(amount := 1, _from_position := Vector2.ZERO) -> void:
	health -= amount
	if health <= 0:
		_break()
	else:
		_flash()


func _flash() -> void:
	if sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.6, 1.6, 1.6), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func _break() -> void:
	collision.set_deferred("disabled", true)
	destroyed.emit()
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
		await tween.finished
	queue_free()
