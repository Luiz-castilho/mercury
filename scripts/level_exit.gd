extends Area2D
## Saída da fase (Godot 4.x). Coloque atrás da porta de saída da sala do chefe:
## quando o jogador passa por aqui, a fase é concluída e o jogo segue para a próxima.

@export var level_id := "mercury"

var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _done or not body.is_in_group("player"):
		return
	_done = true
	SceneManager.complete_level(level_id)
