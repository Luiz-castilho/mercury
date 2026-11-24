@tool
class_name TutorialSign
extends Node2D
## Placa de tutorial (Godot 4.x). Mesmo visual da placa de vento, com um ícone
## por mecânica. Desenhada por código: aparece no editor e não precisa de arte.
## A origem (0, 0) é o pé do poste: coloque no chão.
##
## No texto, {jump} {attack} {grapple} {down} {left} {right} viram as teclas
## configuradas no Mapa de Entrada (ex.: "J / X"). Se você trocar os controles,
## a placa acompanha.

enum Icon { ATTACK, GRAPPLE, POGO, VANISH, DOUBLE_JUMP, CRACK, INFO, WALL_JUMP }

@export var icon := Icon.INFO:
	set(value):
		icon = value
		queue_redraw()
@export var title := "DICA"
@export_multiline var hint := ""
## Distância do jogador em que o texto aparece.
@export var show_distance := 450.0
## Posição do texto (a parte de baixo dele) em relação ao pé do poste.
@export var text_offset := Vector2(0, -150)

const PANEL := Rect2(-46, -122, 92, 60)
const COL_DARK := Color("1d2027")
const COL_PANEL := Color("3a3f4a")
const COL_POST := Color("4a505c")
const COL_POST_LIGHT := Color("6c7482")
const COL_STRIPE := Color("5ad1ff")  # faixa ciano: tutorial (amarelo é perigo)
const COL_ICON := Color("dfe8f5")
const COL_ACCENT := Color("5ad1ff")
const COL_LAMP := Color("5ad1ff")

var _t := 0.0
var _text: Control
var _player: Node2D


func _ready() -> void:
	z_index = -1
	if Engine.is_editor_hint():
		return
	_build_text.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not Engine.is_editor_hint():
		_update_text(delta)
	queue_redraw()


# --- Desenho ----------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(-16, -2, 32, 4), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-12, -7, 24, 7), Color("2b2f38"))
	draw_rect(Rect2(-4, -64, 8, 58), COL_POST)
	draw_rect(Rect2(-4, -64, 2, 58), COL_POST_LIGHT)

	# Luz ciano "respirando" em cima.
	var lamp := Vector2(0, PANEL.position.y - 7)
	draw_rect(Rect2(lamp.x - 8, lamp.y - 1, 16, 8), COL_DARK)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(lamp, 10.0 + pulse * 3.0, Color(COL_LAMP, 0.15 + 0.15 * pulse))
	draw_circle(lamp, 5.0, COL_LAMP)

	draw_rect(PANEL.grow(3), COL_DARK)
	draw_rect(PANEL, COL_PANEL)
	draw_rect(Rect2(PANEL.position.x, PANEL.position.y, PANEL.size.x, 6), COL_STRIPE)
	draw_rect(Rect2(PANEL.position.x, PANEL.end.y - 4, PANEL.size.x, 4), COL_STRIPE)
	for p in [Vector2(PANEL.position.x + 6, PANEL.position.y + 12),
			Vector2(PANEL.end.x - 6, PANEL.position.y + 12)]:
		draw_circle(p, 2.0, COL_POST_LIGHT)

	var c := Vector2(0, PANEL.position.y + 33)  # centro da área do ícone
	match icon:
		Icon.ATTACK: _icon_attack(c)
		Icon.GRAPPLE: _icon_grapple(c)
		Icon.POGO: _icon_pogo(c)
		Icon.VANISH: _icon_vanish(c)
		Icon.DOUBLE_JUMP: _icon_double_jump(c)
		Icon.CRACK: _icon_crack(c)
		Icon.WALL_JUMP: _icon_wall_jump(c)
		_: _icon_info(c)


func _icon_attack(c: Vector2) -> void:
	# Lâmina e o arco do golpe.
	var swing := fmod(_t, 1.6) < 0.25
	draw_arc(c + Vector2(-6, 4), 20.0, -1.9, -0.1, 16, COL_ACCENT if swing else Color(COL_ACCENT, 0.5), 3.0)
	draw_line(c + Vector2(-14, 12), c + Vector2(10, -12), COL_ICON, 4.0)
	draw_line(c + Vector2(-18, 8), c + Vector2(-10, 16), COL_ICON, 3.0)


func _icon_grapple(c: Vector2) -> void:
	# Ponto de ancoragem, corda balançando e o boneco na ponta.
	var anchor := c + Vector2(0, -15)
	var ang := sin(_t * 2.2) * 0.6
	var end := anchor + Vector2(sin(ang), cos(ang)) * 24.0
	draw_circle(anchor, 4.0, COL_ACCENT)
	draw_line(anchor, end, COL_ICON, 2.0)
	draw_circle(end, 4.5, COL_ICON)


func _icon_pogo(c: Vector2) -> void:
	# Seta para baixo quicando em cima de um cristal.
	var bob := absf(sin(_t * 3.0)) * 5.0
	var d := c + Vector2(0, 10)
	draw_colored_polygon(PackedVector2Array([d + Vector2(0, -9), d + Vector2(9, 0),
		d + Vector2(0, 9), d + Vector2(-9, 0)]), COL_ACCENT)
	var tip := c + Vector2(0, -6 - bob)
	draw_line(tip + Vector2(0, -14), tip, COL_ICON, 3.0)
	draw_line(tip, tip + Vector2(-6, -6), COL_ICON, 3.0)
	draw_line(tip, tip + Vector2(6, -6), COL_ICON, 3.0)


func _icon_vanish(c: Vector2) -> void:
	# Plataforma tremendo e sumindo (some e volta em ciclo).
	var phase := fmod(_t, 2.4)
	var alpha := 1.0 if phase < 1.0 else (0.25 if phase < 2.0 else 0.7)
	var shake := sin(_t * 40.0) * 2.0 if phase > 0.6 and phase < 1.0 else 0.0
	var r := Rect2(c.x - 26 + shake, c.y + 2, 52, 9)
	draw_rect(r, Color(COL_ICON, alpha))
	for x in [-14.0, 0.0, 14.0]:
		draw_line(c + Vector2(x, 15), c + Vector2(x, 20), Color(COL_ACCENT, alpha), 2.0)
	draw_circle(c + Vector2(0, -10), 5.0, COL_ICON)  # o jogador em cima


func _icon_double_jump(c: Vector2) -> void:
	# Duas setas para cima, a de cima acendendo.
	var lit := fmod(_t, 1.2) > 0.6
	for i in 2:
		var y := c.y + 10 - i * 13
		var col := COL_ACCENT if (i == 1 and lit) else COL_ICON
		draw_line(Vector2(c.x - 13, y + 7), Vector2(c.x, y - 5), col, 4.0)
		draw_line(Vector2(c.x, y - 5), Vector2(c.x + 13, y + 7), col, 4.0)


func _icon_crack(c: Vector2) -> void:
	# Bloco rachado.
	draw_rect(Rect2(c.x - 18, c.y - 16, 36, 32), COL_ICON, false, 3.0)
	var pts := PackedVector2Array([c + Vector2(-2, -16), c + Vector2(4, -6),
		c + Vector2(-4, 2), c + Vector2(3, 9), c + Vector2(-1, 16)])
	draw_polyline(pts, COL_ACCENT, 2.5)


func _icon_wall_jump(c: Vector2) -> void:
	# Parede à direita e o caminho em zigue-zague subindo (vira, pula, volta).
	draw_rect(Rect2(c.x + 16, c.y - 22, 6, 44), COL_ICON)
	var pts := PackedVector2Array([c + Vector2(12, 18), c + Vector2(-14, 6),
		c + Vector2(12, -4), c + Vector2(-14, -16)])
	draw_polyline(pts, COL_ACCENT, 2.5)
	var k := int(fmod(_t * 2.0, 4.0))
	draw_circle(pts[k], 4.0, COL_ICON)


func _icon_info(c: Vector2) -> void:
	draw_circle(c, 15.0, COL_ACCENT, false, 3.0)
	draw_rect(Rect2(c.x - 2, c.y - 3, 4, 11), COL_ICON)
	draw_circle(c + Vector2(0, -8), 2.5, COL_ICON)


# --- Texto de dica ----------------------------------------------------------

func _build_text() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 2)
	box.add_child(_make_label(title, 26, COL_ACCENT))
	if hint != "":
		box.add_child(_make_label(format_keys(hint), 16, Color("e8ecf4")))
	box.modulate.a = 0.0
	add_child(box)
	var size := box.get_combined_minimum_size()
	box.size = size
	box.position = text_offset - Vector2(size.x / 2.0, size.y)
	_text = box


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _update_text(delta: float) -> void:
	if _text == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var near := _player != null \
		and _player.global_position.distance_to(global_position) < show_distance
	_text.modulate.a = move_toward(_text.modulate.a, 1.0 if near else 0.0, delta * 4.0)


## Troca {acao} pelas teclas da ação no Mapa de Entrada (até duas).
static func format_keys(text: String) -> String:
	var names := {"jump": "jump", "attack": "attack", "grapple": "grapple",
		"down": "move_down", "left": "move_left", "right": "move_right", "dash": "dash"}
	for key in names:
		var tag := "{%s}" % key
		if text.contains(tag):
			text = text.replace(tag, _keys_for(names[key]))
	return text


static func _keys_for(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	var parts: Array[String] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			parts.append(OS.get_keycode_string(code))
		elif event is InputEventJoypadButton:
			parts.append("Botão %d" % event.button_index)
		if parts.size() >= 2:
			break
	return " / ".join(parts) if not parts.is_empty() else action
