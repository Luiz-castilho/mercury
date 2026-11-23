extends Area2D
## Bandeira de checkpoint. Use index 0, 1 e 2 (o último fica antes do chefe).

@export var index := 0
@export var activated_sprite: Node2D  # opcional: algo que acende ao ativar

var _activated := false


func _ready() -> void:
	add_to_group("checkpoints")
	body_entered.connect(_on_body_entered)
	if SceneManager.get_checkpoint() >= index:
		_activate(false)


func _on_body_entered(body: Node2D) -> void:
	if _activated or not body.is_in_group("player"):
		return
	_activate(true)


func _activate(save: bool) -> void:
	_activated = true
	if save:
		SceneManager.set_checkpoint(index)
	if activated_sprite:
		activated_sprite.visible = true
