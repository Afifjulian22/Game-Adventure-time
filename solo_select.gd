extends Control

## Panel pilihan level/kesulitan setelah menekan MAIN SENDIRIAN.
## Tiga pilihan: MAP MUDAH / MAP NORMAL / MAP SULIT.
## Setiap pilihan memuat scene map kesulitan masing-masing
## (map_easy.tscn / map_normal.tscn / map_sulit.tscn).

signal level_selected(mode: String)

const C_GOLD := Color(1.0, 0.84, 0.5)
const C_TEXT := Color(1.0, 0.97, 0.92)
const C_DIM := Color(1.0, 1.0, 1.0, 0.62)
const C_PANEL := Color(0.05, 0.055, 0.08, 0.97)
const C_BTN := Color(0.1, 0.11, 0.15, 0.92)
const C_BTN_HOVER := Color(0.17, 0.18, 0.24, 0.96)
const C_GREEN := Color(0.42, 0.92, 0.55)
const C_ORANGE := Color(1.0, 0.72, 0.42)

const OPTIONS := [
	{
		"mode": "Mudah",
		"title": "MAP MUDAH",
		"scene": "map_easy.tscn",
		"accent": C_GREEN,
		"desc": "Rintangan sedikit, trap lambat, platform lebih sabar jatuh. Cocok untuk santai.",
	},
	{
		"mode": "Normal",
		"title": "MAP NORMAL",
		"scene": "map_normal.tscn",
		"accent": C_GOLD,
		"desc": "Rintangan lebih banyak, trap lebih cepat, dan level lebih sulit diselesaikan.",
	},
	{
		"mode": "Sulit",
		"title": "MAP SULIT",
		"scene": "map_sulit.tscn",
		"accent": C_ORANGE,
		"desc": "Rintangan paling banyak, trap sangat cepat, platform cepat jatuh, plus rintangan ekstra.",
	},
]

var _first_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func open() -> void:
	visible = true
	move_to_front()
	if _first_button != null:
		_first_button.grab_focus()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ==================================================================== UI
func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL, Color(1.0, 0.8, 0.42, 0.4), 24))
	center.add_child(panel)

	var margin := MarginContainer.new()
	_margins(margin, 46, 34, 46, 34)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)

	var title := _label("PILIH LEVEL", 38, C_GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var sub := _label("Pilih map / tingkat kesulitan untuk main sendirian.", 14, C_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)

	for opt in OPTIONS:
		v.add_child(_make_option(opt))

	var back := _button("KEMBALI")
	back.custom_minimum_size = Vector2(0, 50)
	back.pressed.connect(close)
	v.add_child(back)


func _make_option(opt: Dictionary) -> Button:
	var accent: Color = opt["accent"]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 108)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL
	_style_option(btn, accent)
	btn.pressed.connect(_on_option_pressed.bind(String(opt["mode"])))

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins(m, 20, 14, 20, 14)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(m)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(inner)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(head)

	var dot := ColorRect.new()
	dot.color = accent
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(dot)

	var t := _label(String(opt["title"]), 24, C_TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(t)

	var scene_name := _label("res://" + String(opt["scene"]), 12, C_DIM)
	scene_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scene_name.add_theme_color_override("font_color", accent)
	head.add_child(scene_name)

	var d := _label(String(opt["desc"]), 14, C_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(d)

	if _first_button == null:
		_first_button = btn
	return btn


func _on_option_pressed(mode: String) -> void:
	close()
	level_selected.emit(mode)


# ==================================================================== util
func _button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_stylebox_override("normal", _panel_style(C_BTN, Color(1.0, 0.8, 0.42, 0.5), 14))
	btn.add_theme_stylebox_override("hover", _panel_style(C_BTN_HOVER, C_GOLD, 14))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.06, 0.07, 0.1, 1), C_GOLD, 14))
	btn.add_theme_stylebox_override("focus", _panel_style(C_BTN_HOVER, C_GOLD, 14))
	btn.add_theme_color_override("font_color", C_TEXT)
	return btn


func _style_option(btn: Button, accent: Color) -> void:
	btn.add_theme_stylebox_override("normal", _panel_style(C_BTN, Color(accent.r, accent.g, accent.b, 0.45), 16, 2, 12))
	btn.add_theme_stylebox_override("hover", _panel_style(C_BTN_HOVER, accent, 16, 2, 12))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.05, 0.06, 0.09, 1), accent, 16, 3, 12))
	btn.add_theme_stylebox_override("focus", _panel_style(C_BTN_HOVER, accent, 16, 2, 12))


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05, 1))
		l.add_theme_constant_override("outline_size", 6)
	return l


func _margins(node: MarginContainer, l: int, t: int, r: int, b: int) -> void:
	node.add_theme_constant_override("margin_left", l)
	node.add_theme_constant_override("margin_top", t)
	node.add_theme_constant_override("margin_right", r)
	node.add_theme_constant_override("margin_bottom", b)


func _panel_style(bg: Color, border: Color, radius: int, bw: int = 2, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = int(pad * 0.6)
	sb.content_margin_bottom = int(pad * 0.6)
	return sb
