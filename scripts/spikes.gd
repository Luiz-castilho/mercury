extends Area2D
## Espinhos de rocha (Godot 4.x). Area2D com CollisionShape2D cobrindo os espinhos
## e um Sprite2D. Máscara de colisão na camada do jogador.

@export var damage := 1
## Depois de ferir, devolve o jogador ao último chão seguro (evita dano repetido).
@export var return_to_safe := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	body.take_damage(damage, global_position)
	if return_to_safe and body.health > 0:
		body.return_to_safe_position()
