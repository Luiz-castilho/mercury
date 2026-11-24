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
## false: ao abrir o jogo, a fase começa do início (o checkpoint salvo só vale
## dentro da mesma sessão). Troque para true quando existir "Continuar" no menu.
const RESUME_CHECKPOINT_ON_LAUNCH := false
const END_OF_DEMO_TEXT := "Fim da demo\nObrigado por jogar!"

## Uma fase por planeta. Ajuste os caminhos para os seus arquivos .tscn.
## Mercúrio usa o uid da cena: continua funcionando mesmo se você renomear ou
## mover o arquivo pelo editor (ex.: para res://scenes/levels/mercury.tscn).
## Fases cujo arquivo ainda não existe são puladas (veja complete_level).
## "minigame_before": quando true, o minigame de nave roda antes da fase
## (ainda não implementado: veja _run_minigame_before).
const LEVELS := {
	"mercury": {
		"name": "Mercúrio",
		"path": "uid://c2ytre4ro1s43",
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
## Melhorias encontradas pelo jogador (ex.: "double_jump"). Valem para o jogo
## todo, não só para a fase onde foram achadas.
var upgrades: Array = []

var _is_transitioning := false
var _fade: ColorRect
var _message: Label


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
	if not is_level_available(level_id):
		push_error("SceneManager: arquivo da fase não encontrado: %s" % LEVELS[level_id]["path"])
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
	if next_id != "" and is_level_available(next_id):
		go_to_level(next_id)
	elif next_id != "":
		# Próximo planeta ainda não foi feito: encerra a demo.
		_end_of_demo()
	else:
		go_to_main_menu()


## true se o arquivo .tscn da fase existe no projeto.
func is_level_available(level_id: String) -> bool:
	return LEVELS.has(level_id) and ResourceLoader.exists(LEVELS[level_id]["path"])


func go_to_main_menu() -> void:
	if _is_transitioning:
		return
	if not ResourceLoader.exists(MAIN_MENU):
		# Ainda não há menu: volta para a primeira fase, do início.
		go_to_level(LEVELS.keys()[0])
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


# --- Melhorias (upgrades) ----------------------------------------------------

func unlock_upgrade(upgrade_id: String) -> void:
	if not upgrades.has(upgrade_id):
		upgrades.append(upgrade_id)
		save_progress()


func has_upgrade(upgrade_id: String) -> bool:
	return upgrades.has(upgrade_id)


# --- Save / load ------------------------------------------------------------

func get_state(level_id: String) -> Dictionary:
	if not progress.has(level_id):
		progress[level_id] = {"completed": false, "checkpoint": -1, "collected": []}
	return progress[level_id]


func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"levels": progress, "upgrades": upgrades}))


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		if data.has("levels"):
			progress = data["levels"]
			upgrades = data.get("upgrades", [])
		else:  # formato antigo do save
			progress = data
	if not RESUME_CHECKPOINT_ON_LAUNCH:
		# Jogo novo a cada abertura: volta ao início da fase e sem melhorias.
		upgrades.clear()
		for id in progress:
			progress[id]["checkpoint"] = -1


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
	_message = Label.new()
	_message.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 48)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.modulate.a = 0.0
	layer.add_child(_message)


## Tela de fim de demo: escurece, mostra a mensagem e volta para o começo.
func _end_of_demo() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	transition_started.emit()
	await _fade_to(1.0)
	_message.text = END_OF_DEMO_TEXT
	await create_tween().tween_property(_message, "modulate:a", 1.0, FADE_TIME).finished
	await get_tree().create_timer(3.0).timeout
	await create_tween().tween_property(_message, "modulate:a", 0.0, FADE_TIME).finished
	upgrades.clear()  # a próxima partida começa do zero
	_is_transitioning = false
	go_to_main_menu()


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, FADE_TIME)
	await tween.finished
