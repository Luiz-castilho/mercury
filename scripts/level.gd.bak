class_name LevelBase
extends Node2D
## Script-base para a cena de cada fase (ex.: mercury.tscn).
## Coloque o jogador no grupo "player" e os checkpoints no grupo "checkpoints"
## (o script checkpoint.gd já faz isso).

@export var level_id := "mercury"
@export var player: Node2D
@export var start_position: Marker2D


func _ready() -> void:
	SceneManager.current_level_id = level_id
	player.global_position = _get_spawn_position()
	if player.has_signal("died"):
		player.died.connect(_on_player_died)


func _get_spawn_position() -> Vector2:
	var index := SceneManager.get_checkpoint(level_id)
	if index >= 0:
		for cp in get_tree().get_nodes_in_group("checkpoints"):
			if cp.index == index:
				return cp.global_position
	return start_position.global_position


func _on_player_died() -> void:
	SceneManager.restart_from_checkpoint()


## Chame ao derrotar o chefe (ex.: no sinal "defeated" do chefe).
func finish_level() -> void:
	SceneManager.complete_level(level_id)
