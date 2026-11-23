extends Area2D
## Esfera de energia do chefe (Godot 4.x). Salve como cena: Area2D com
## CollisionShape2D (círculo) e Sprite2D, e arraste a cena para o campo
## "Projectile Scene" do chefe. O chefe define a velocidade ao disparar.
## Máscara de colisão: jogador e chão/paredes (não o chefe).

@export var damage := 1
@export var lifetime := 6.0

var velocity := Vector2.ZERO


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage, global_position)
		queue_free()
	elif not body.is_in_group("enemy"):
		queue_free()  # bateu no chão ou na parede
