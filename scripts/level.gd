class_name LevelBase
extends Node2D
## Script-base para a cena de cada fase (ex.: mercury.tscn).
## Coloque o jogador no grupo "player" e os checkpoints no grupo "checkpoints"
## (o script checkpoint.gd já faz isso).

@export var level_id := "mercury"
@export var player: Node2D
@export var start_position: Marker2D
## Limites da câmera na fase (dois Marker2D: canto superior esquerdo e inferior direito).
@export var camera_top_left: Marker2D
@export var camera_bottom_right: Marker2D
## Distância abaixo do limite inferior da câmera em que a queda é considerada fatal.
@export var fall_margin := 100.0


func _ready() -> void:
	SceneManager.current_level_id = level_id
	player.global_position = _get_spawn_position()
	_setup_camera()
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


func _setup_camera() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	if camera_top_left:
		cam.limit_left = int(camera_top_left.global_position.x)
		cam.limit_top = int(camera_top_left.global_position.y)
	if camera_bottom_right:
		cam.limit_right = int(camera_bottom_right.global_position.x)
		cam.limit_bottom = int(camera_bottom_right.global_position.y)
		# Quem cai abaixo da câmera volta logo, em vez de despencar fora da tela.
		if "fall_death_y" in player:
			player.fall_death_y = camera_bottom_right.global_position.y + fall_margin
	cam.reset_smoothing()  # a câmera já começa no jogador, sem deslizar de longe
