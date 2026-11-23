class_name BossDoor
extends StaticBody2D
## Porta da sala do chefe (Godot 4.x). StaticBody2D com um CollisionShape2D
## (retângulo alto, do tamanho da passagem) e um Sprite2D. Fechada ela bloqueia
## a passagem; aberta ela sobe e libera. Quem controla é o boss_room.gd.

## Quanto a porta se desloca ao abrir (para cima, por padrão).
@export var open_offset := Vector2(0.0, -192.0)
@export var move_time := 0.5
## true: a porta começa fechada (ex.: a porta de saída, que abre quando o chefe cai).
@export var start_closed := false

var is_closed := false

var _closed_position := Vector2.ZERO


func _ready() -> void:
	_closed_position = position
	is_closed = start_closed
	if not start_closed:
		position = _closed_position + open_offset


func close() -> void:
	is_closed = true
	_move_to(_closed_position)


func open() -> void:
	is_closed = false
	_move_to(_closed_position + open_offset)


func _move_to(target: Vector2) -> void:
	create_tween().tween_property(self, "position", target, move_time)
