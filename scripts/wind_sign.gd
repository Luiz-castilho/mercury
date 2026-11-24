@tool
class_name WindSign
extends Node2D
## Placa de aviso de vento forte (Godot 4.x). Desenhada por código: funciona sem
## arte e aparece no editor. A origem (0, 0) é o pé do poste: coloque no chão.
##
## Ligue "wind_zone" à WindZone da área: as setas apontam na direção do vento,
## a lâmpada pisca no aviso e fica acesa durante a rajada. Quando o jogador chega
## perto, aparece o texto de dica acima da placa.

@export var wind_zone: Area2D
## Usado só se não houver wind_zone: -1 = vento para a esquerda, 1 = direita.
@export var arrow_direction := -1
@export var title := "VENTO FORTE"
@export_multiline var hint := "Rajadas empurram você.\nEspere a calmaria ou atravesse com o dash."
## Distância do jogador em que o texto aparece.
@export var show_distance := 450.0
## Posição do texto (a parte de baixo dele) em relação ao pé do poste.
@export var text_offset := Vector2(0, -150)

const PANEL := Rect2(-46, -122, 92, 60)
const COL_DARK := Color("1d2027")
const COL_PANEL := Color("3a3f4a")
const COL_POST := Color("4a505c")
const COL_POST_LIGHT := Color("6c7482")
const COL_HAZARD := Color("f2b632")
const COL_ARROW := Color("dfe8f5")
const COL_LAMP_OFF := Color("5a3a1c")
const COL_LAMP_ON := Color("ff9a2e")

var _t := 0.0
var _text: Control
var _player: Node2D


func _ready() -> void:
	z_index = -1  # o jogador passa na frente da placa
	if Engine.is_editor_hint():
		return
	_build_text.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not Engine.is_editor_hint():
		_update_text(delta)
	queue_redraw()


# --- Estado do vento --------------------------------------------------------

func _dir() -> float:
	if wind_zone:
		var d = wind_zone.get("direction")
		if d is Vector2 and d.x != 0.0:
			return signf(d.x)
	return -1.0 if arrow_direction < 0 else 1.0


func _gusting() -> bool:
	return not Engine.is_editor_hint() and wind_zone != null \
		and wind_zone.has_method("is_gusting") and wind_zone.is_gusting()


func _warning() -> bool:
	return not Engine.is_editor_hint() and wind_zone != null \
		and wind_zone.has_method("is_warning") and wind_zone.is_warning()


# --- Desenho ----------------------------------------------------------------

func _draw() -> void:
	# Base e poste.
	draw_rect(Rect2(-16, -2, 32, 4), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-12, -7, 24, 7), Color("2b2f38"))
	draw_rect(Rect2(-4, -64, 8, 58), COL_POST)
	draw_rect(Rect2(-4, -64, 2, 58), COL_POST_LIGHT)

	# Lâmpada em cima do painel.
	var lamp := Vector2(0, PANEL.position.y - 7)
	draw_rect(Rect2(lamp.x - 8, lamp.y - 1, 16, 8), COL_DARK)
	var lit := _gusting() or (_warning() and fmod(_t, 0.25) < 0.125)
	if lit:
		draw_circle(lamp, 12.0, Color(COL_LAMP_ON, 0.25))
	draw_circle(lamp, 5.0, COL_LAMP_ON if lit else COL_LAMP_OFF)

	# Painel.
	draw_rect(PANEL.grow(3), COL_DARK)
	draw_rect(PANEL, COL_PANEL)
	_draw_hazard_band(Rect2(PANEL.position.x, PANEL.position.y, PANEL.size.x, 9))
	_draw_hazard_band(Rect2(PANEL.position.x, PANEL.end.y - 6, PANEL.size.x, 6))
	# Parafusos.
	for p in [Vector2(PANEL.position.x + 6, PANEL.position.y + 15),
			Vector2(PANEL.end.x - 6, PANEL.position.y + 15)]:
		draw_circle(p, 2.0, COL_POST_LIGHT)

	# Setas de vento (andam na direção do vento durante a rajada).
	var d := _dir()
	var shift := 0.0
	if _gusting():
		shift = fmod(_t * 50.0, 10.0) - 5.0
	var center_y := PANEL.position.y + 22.0
	for i in 3:
		var y := center_y + i * 11.0
		var half := 26.0 - absf(i - 1.0) * 8.0
		var off := (i - 1.0) * 4.0 * d + shift * d
		var tail := Vector2(-d * half + off, y)
		var tip := Vector2(d * half + off, y)
		draw_line(tail, tip, COL_ARROW, 3.0)
		draw_line(tip, tip + Vector2(-d * 7.0, -5.0), COL_ARROW, 3.0)
		draw_line(tip, tip + Vector2(-d * 7.0, 5.0), COL_ARROW, 3.0)


func _draw_hazard_band(band: Rect2) -> void:
	draw_rect(band, COL_HAZARD)
	var x := band.position.x - band.size.y
	while x < band.end.x:
		var pts := PackedVector2Array()
		for p in [Vector2(x, band.end.y), Vector2(x + 6.0, band.end.y),
				Vector2(x + 6.0 + band.size.y, band.position.y),
				Vector2(x + band.size.y, band.position.y)]:
			pts.append(Vector2(clampf(p.x, band.position.x, band.end.x), p.y))
		draw_colored_polygon(pts, COL_DARK)
		x += 12.0


# --- Texto de dica ----------------------------------------------------------

func _build_text() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 2)
	box.add_child(_make_label(title, 26, COL_HAZARD))
	box.add_child(_make_label(hint, 16, Color("e8ecf4")))
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
