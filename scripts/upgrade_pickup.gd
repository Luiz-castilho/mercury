@tool
class_name UpgradePickup
extends Area2D
## Melhoria que o jogador encontra no mapa (Godot 4.x). Ex.: pulo duplo.
## Estrutura: UpgradePickup (Area2D) + CollisionShape2D. Máscara na camada do
## jogador (1). Desenhada por código: um módulo ciano flutuando.
## Ao pegar: libera a melhoria no SceneManager (vale até o fim da partida) e
## mostra um aviso na tela com a dica de uso.

@export var upgrade_id := "double_jump"
@export var title := "PULO DUPLO"
## {jump}, {attack} etc. viram as teclas configuradas (veja tutorial_sign.gd).
@export_multiline var hint := "Aperte {jump} de novo no ar para pular mais uma vez."

const COL_GLOW := Color("5ad1ff")
const COL_CORE := Color("dff6ff")
const COL_DARK := Color("1d2027")

var _t := 0.0
var _taken := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	body_entered.connect(_on_body_entered)
	var manager := get_node_or_null("/root/SceneManager")
	if manager and manager.has_upgrade(upgrade_id):
		queue_free()  # já pegou nesta partida


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 2.5) * 6.0
	var c := Vector2(0, bob)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(c, 34.0 + pulse * 6.0, Color(COL_GLOW, 0.10 + 0.08 * pulse))
	draw_circle(c, 24.0, Color(COL_GLOW, 0.18))
	var hexa := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i + 30.0)
		hexa.append(c + Vector2(cos(a), sin(a)) * 18.0)
	draw_colored_polygon(hexa, COL_DARK)
	hexa.append(hexa[0])
	draw_polyline(hexa, COL_GLOW, 3.0)
	# Duas setas para cima (pulo duplo).
	for i in 2:
		var y := c.y + 6 - i * 9
		draw_line(Vector2(c.x - 8, y + 4), Vector2(c.x, y - 4), COL_CORE, 3.0)
		draw_line(Vector2(c.x, y - 4), Vector2(c.x + 8, y + 4), COL_CORE, 3.0)
	# Faíscas girando.
	for i in 3:
		var a := _t * 2.0 + TAU * i / 3.0
		draw_circle(c + Vector2(cos(a), sin(a)) * 28.0, 2.5, COL_CORE)


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	var manager := get_node_or_null("/root/SceneManager")
	if manager:
		manager.unlock_upgrade(upgrade_id)
	if body.has_method("refresh_upgrades"):
		body.refresh_upgrades()
	_show_banner()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


## Aviso no meio da tela. Fica numa CanvasLayer própria, que se apaga sozinha.
func _show_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	get_tree().current_scene.add_child(layer)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sub := Label.new()
	sub.text = "MELHORIA ENCONTRADA"
	var head := Label.new()
	head.text = title
	var tip := Label.new()
	tip.text = load("res://scripts/tutorial_sign.gd").format_keys(hint)
	for pair in [[sub, 20, Color("e8ecf4")], [head, 54, COL_GLOW], [tip, 22, Color("e8ecf4")]]:
		var label: Label = pair[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", pair[1])
		label.add_theme_color_override("font_color", pair[2])
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", 8)
		box.add_child(label)
	box.modulate.a = 0.0
	layer.add_child(box)
	var tween := layer.create_tween()
	tween.tween_property(box, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.8)
	tween.tween_property(box, "modulate:a", 0.0, 0.6)
	tween.tween_callback(layer.queue_free)
