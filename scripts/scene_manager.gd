extends Node
## Autoload (Godot 4.x). Em Projeto > Configurações do Projeto > Globais (Autoload),
## adicione este script com o nome "SceneManager".

signal transition_started
signal transition_finished
signal level_started(level_id: String)
signal level_completed(level_id: String)

const FADE_TIME := 0.4
const SAVE_PATH := "user://save.json"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

## Uma fase por planeta. Ajuste os caminhos para os seus arquivos .tscn.
## "minigame_before": quando true, o minigame de nave roda antes da fase
## (ainda não implementado: veja _run_minigame_before).
const LEVELS := {
	"mercury": {
		"name": "Mercúrio",
		"path": "res://scenes/levels/mercury.tscn",
		"next": "venus",
		"minigame_before": false,
	},
	"venus": {
		"name": "Vênus",
		"path": "res://scenes/levels/venus.tscn",
		"next": "mars",
		"minigame_before": true,
	},
	"mars": {
		"name": "Marte",
		"path": "res://scenes/levels/mars.tscn",
		"next": "",
		"minigame_before": true,
	},
}

## Progresso por fase: { id: { completed: bool, checkpoint: int, collected: Array } }
## checkpoint = -1 significa "começar do início da fase".
var progress: Dictionary = {}
var current_level_id := ""

var _is_transitioning := false
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade_layer()
	load_progress()


# --- Troca de fases ---------------------------------------------------------

## Vai para uma fase. keep_checkpoint = true retoma do último checkpoint
## (usado ao morrer); false começa do início (usado ao revisitar uma fase).
func go_to_level(level_id: String, keep_checkpoint := false) -> void:
	if _is_transitioning:
		return
	if not LEVELS.has(level_id):
		push_error("SceneManager: fase desconhecida '%s'" % level_id)
		return

	_is_transitioning = true
	transition_started.emit()
	await _fade_to(1.0)

	if not keep_checkpoint:
		get_state(level_id)["checkpoint"] = -1

	if LEVELS[level_id].get("minigame_before", false):
		await _run_minigame_before(level_id)

	var err := get_tree().change_scene_to_file(LEVELS[level_id]["path"])
	if err != OK:
		push_error("SceneManager: não foi possível carregar %s" % LEVELS[level_id]["path"])
	current_level_id = level_id

	# Espera a nova cena entrar na árvore antes de clarear a tela.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0)

	_is_transitioning = false
	transition_finished.emit()
	level_started.emit(level_id)


## Chamado quando o jogador morre: recomeça no último checkpoint.
func restart_from_checkpoint() -> void:
	go_to_level(current_level_id, true)


## Chamado ao derrotar o chefe / chegar ao fim da fase.
func complete_level(level_id: String) -> void:
	get_state(level_id)["completed"] = true
	save_progress()
	level_completed.emit(level_id)
	var next_id: String = LEVELS[level_id].get("next", "")
	if next_id == "":
		go_to_main_menu()
	else:
		go_to_level(next_id)


func go_to_main_menu() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	transition_started.emit()
	await _fade_to(1.0)
	get_tree().change_scene_to_file(MAIN_MENU)
	current_level_id = ""
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0)
	_is_transitioning = false
	transition_finished.emit()


# --- Revisita de fases ------------------------------------------------------

func is_completed(level_id: String) -> bool:
	return get_state(level_id)["completed"]


## Fases que o jogador pode revisitar (já concluídas).
func get_revisitable_levels() -> Array[String]:
	var result: Array[String] = []
	for id in LEVELS.keys():
		if is_completed(id):
			result.append(id)
	return result


# --- Checkpoints ------------------------------------------------------------

func set_checkpoint(index: int, level_id := "") -> void:
	var id := level_id if level_id != "" else current_level_id
	var state := get_state(id)
	if index > int(state["checkpoint"]):
		state["checkpoint"] = index
		save_progress()


func get_checkpoint(level_id := "") -> int:
	var id := level_id if level_id != "" else current_level_id
	return int(get_state(id)["checkpoint"])


# --- Coletáveis (espaço reservado; ainda sem contador/HUD) ------------------

func collect(item_id: String, level_id := "") -> void:
	var id := level_id if level_id != "" else current_level_id
	var collected: Array = get_state(id)["collected"]
	if not collected.has(item_id):
		collected.append(item_id)
		save_progress()


func has_collected(item_id: String, level_id := "") -> bool:
	var id := level_id if level_id != "" else current_level_id
	return get_state(id)["collected"].has(item_id)


# --- Save / load ------------------------------------------------------------

func get_state(level_id: String) -> Dictionary:
	if not progress.has(level_id):
		progress[level_id] = {"completed": false, "checkpoint": -1, "collected": []}
	return progress[level_id]


func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(progress))


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		progress = data


# --- Minigame de nave (ainda não implementado) ------------------------------

## Ponto de entrada para o minigame "space invaders" que roda antes da fase.
## Quando existir, troque o corpo por algo como:
##   get_tree().change_scene_to_file("res://scenes/minigame/ship.tscn")
##   await minigame_finished
func _run_minigame_before(_level_id: String) -> void:
	await get_tree().process_frame


# --- Transição --------------------------------------------------------------

func _build_fade_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, FADE_TIME)
	await tween.finished
