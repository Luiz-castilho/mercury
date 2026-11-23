extends HBoxContainer
class_name HealthBar

## Barra de vida do jogador (Godot 4.x): uma fileira de hexágonos, um por ponto
## de vida. Escuta o sinal health_changed do Player.
## Sem texturas, desenha hexágonos por código (serve para testar sem arte).
##
## Estrutura: CanvasLayer > HealthBar (este script). Posicione no canto superior esquerdo.

## Se vazio, é procurado o nó do grupo "player".
@export var player: Player
@export var full_texture: Texture2D
@export var empty_texture: Texture2D
@export var icon_size := Vector2(44, 44)
@export var spacing := 8
@export var full_color := Color("5ad1ff")
@export var empty_color := Color(1.0, 1.0, 1.0, 0.25)
@export var damage_color := Color("ff5a4d")

var _icons: Array[Control] = []
var _last_health := -1


class HexIcon:
	extends Control
	var filled := true
	var full_color := Color.WHITE
	var empty_color := Color.GRAY

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 2.0
		var points := PackedVector2Array()
		for i in 6:
			var angle := deg_to_rad(60.0 * i)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		if filled:
			draw_colored_polygon(points, full_color)
		else:
			points.append(points[0])
			draw_polyline(points, empty_color, 2.0)


func _ready() -> void:
	add_theme_constant_override("separation", spacing)
	# Espera um frame: o Player entra no grupo "player" no próprio _ready.
	_setup.call_deferred()


func _setup() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_warning("HealthBar: Player não encontrado.")
		return
	player.health_changed.connect(_on_health_changed)
	_build(player.max_health)
	_on_health_changed(player.health, player.max_health)


func _build(max_health: int) -> void:
	for child in get_children():
		child.queue_free()
	_icons.clear()
	for i in max_health:
		var icon := _make_icon()
		add_child(icon)
		_icons.append(icon)


func _make_icon() -> Control:
	var icon: Control
	if full_texture:
		var rect := TextureRect.new()
		rect.texture = full_texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon = rect
	else:
		var hex := HexIcon.new()
		hex.full_color = full_color
		hex.empty_color = empty_color
		icon = hex
	icon.custom_minimum_size = icon_size
	icon.pivot_offset = icon_size / 2.0
	return icon


func _on_health_changed(current: int, maximum: int) -> void:
	if _icons.size() != maximum:
		_build(maximum)
	for i in _icons.size():
		_set_filled(_icons[i], i < current)
	# Feedback de dano: o hexágono perdido pisca em vermelho e "estoura".
	if _last_health > current and current >= 0 and current < _icons.size():
		for i in range(current, mini(_last_health, _icons.size())):
			_pulse(_icons[i])
	_last_health = current


func _set_filled(icon: Control, filled: bool) -> void:
	if icon is TextureRect:
		var rect := icon as TextureRect
		if filled:
			rect.texture = full_texture
			rect.modulate = Color.WHITE
		elif empty_texture:
			rect.texture = empty_texture
			rect.modulate = Color.WHITE
		else:
			rect.texture = full_texture
			rect.modulate = Color(1.0, 1.0, 1.0, 0.2)
	elif icon is HexIcon:
		(icon as HexIcon).filled = filled
		icon.queue_redraw()


func _pulse(icon: Control) -> void:
	var original := icon.modulate
	icon.modulate = damage_color
	icon.scale = Vector2(1.5, 1.5)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.25)
	tween.tween_property(icon, "modulate", original, 0.25)
