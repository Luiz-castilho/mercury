extends Node2D
## Ponto de ancoragem do gancho. Coloque na cena da fase (Node2D + Sprite2D).
## Arraste o Sprite2D para o campo "sprite" para ele brilhar quando alcançável.

@export var sprite: CanvasItem
@export var idle_color := Color(1.0, 1.0, 1.0, 0.8)
@export var active_color := Color(0.4, 0.9, 1.0, 1.0)


func _ready() -> void:
	add_to_group("grapple_point")
	set_highlight(false)


func set_highlight(on: bool) -> void:
	if sprite:
		sprite.modulate = active_color if on else idle_color
