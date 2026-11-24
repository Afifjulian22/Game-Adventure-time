extends Control

## Menu CUSTOMIZE: memilih skin karakter yang dipakai saat bermain.
## Pilihan disimpan di Net (otomatis tersimpan ke user://settings.cfg)
## dan ikut dikirim ke pemain lain saat mulai main.

const C_GOLD := Color(1.0, 0.84, 0.5)
const C_TEXT := Color(1.0, 0.96, 0.9)
const C_DIM := Color(1.0, 1.0, 1.0, 0.58)
const C_GREEN := Color(0.42, 0.92, 0.55)
const C_PANEL := Color(0.04, 0.05, 0.075, 0.74)
const C_BTN := Color(0.09, 0.1, 0.14, 0.94)
const C_BTN_HOVER := Color(0.16, 0.17, 0.23, 0.98)
const C_BORDER := Color(1.0, 1.0, 1.0, 0.16)

var _net: Node
var _grid: GridContainer
var _current_label: Label


func _ready() -> void:
	_net = get_node("/root/Net")
	_build_ui()
	_rebuild_cards()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


# ==================================================================== UI
func _build_ui() -> void:
	var vid := VideoStreamPlayer.new()
	vid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vid.expand = true
	vid.autoplay = true
	vid.stream = load("res://Free/Background/village.ogv")
	add_child(vid)

	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.56)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins(margin, 30, 26, 30, 26)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)

	var title := _label("CUSTOMIZE", 40, C_GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	_current_label = _label("", 16, C_TEXT)
	_current_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_current_label)

	var sub := _label("Pilih skin karaktermu. Berlaku untuk mode sendirian maupun multiplayer.", 15, C_DIM)
	v.add_child(sub)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_BORDER, 22, 2, 12))
	v.add_child(panel)

	var pm := MarginContainer.new()
	_margins(pm, 22, 20, 22, 20)
	panel.add_child(pm)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	pm.add_child(_grid)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)

	var note := _label("Pilihan tersimpan otomatis dan dipakai pada permainan berikutnya.", 13, C_DIM)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(note)

	var back := _small_button("KEMBALI")
	back.custom_minimum_size = Vector2(240, 52)
	back.pressed.connect(_on_back_pressed)
	foot.add_child(back)


func _make_card(skin: String) -> Button:
	var selected: bool = skin == String(_net.my_skin)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 330)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	_style_card(btn, selected)
	btn.pressed.connect(_on_skin_pressed.bind(skin))

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins(m, 14, 16, 14, 14)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)

	var art := TextureRect.new()
	art.texture = _preview_texture(skin)
	art.custom_minimum_size = Vector2(0, 190)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(art)

	var name_l := _label(skin, 22, C_TEXT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)

	var badge := _label("DIPAKAI" if selected else "PILIH", 13, C_GREEN if selected else C_DIM)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(badge)

	return btn


func _rebuild_cards() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for skin in _net.SKINS:
		_grid.add_child(_make_card(String(skin)))
	_current_label.text = "Skin sekarang: " + String(_net.my_skin)


# ==================================================================== aksi
func _on_skin_pressed(skin: String) -> void:
	_net.set_my_skin(skin)
	_rebuild_cards()


func _on_back_pressed() -> void:
	_net.back_to_menu()


# ==================================================================== util
func _preview_texture(skin: String) -> AtlasTexture:
	var at := AtlasTexture.new()
	if skin == "Afif":
		at.atlas = load("res://Free/Main Characters/Afif/aligned/afif-aligned.png")
		# Potong area kosong di sekitar karakter agar preview tidak kecil.
		at.region = Rect2(38, 53, 58, 82)
	else:
		at.atlas = load("res://Free/Main Characters/%s/Idle (32x32).png" % skin)
		at.region = Rect2(0, 0, 32, 32)
	return at


func _style_card(btn: Button, selected: bool) -> void:
	var bg := Color(0.17, 0.14, 0.08, 0.96) if selected else C_BTN
	var border := C_GOLD if selected else Color(1, 1, 1, 0.28)
	btn.add_theme_stylebox_override("normal", _panel_style(bg, border, 18, 2, 10))
	btn.add_theme_stylebox_override("hover", _panel_style(C_BTN_HOVER, C_GOLD, 18, 2, 10))
	btn.add_theme_stylebox_override("pressed", _panel_style(bg, C_GOLD, 18, 2, 10))
	btn.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 18, 0, 10))


func _small_button(text: String, accent: Color = Color(1, 1, 1, 0.35)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 52)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_stylebox_override("normal", _panel_style(C_BTN, Color(accent.r, accent.g, accent.b, 0.45), 16, 2, 16))
	btn.add_theme_stylebox_override("hover", _panel_style(C_BTN_HOVER, accent, 16, 2, 16))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.05, 0.06, 0.09, 1), accent, 16, 2, 16))
	btn.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 16, 0, 16))
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	return btn


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05, 1))
		l.add_theme_constant_override("outline_size", 8)
	return l


func _margins(node: Control, l: int, t: int, r: int, b: int) -> void:
	node.add_theme_constant_override("margin_left", l)
	node.add_theme_constant_override("margin_top", t)
	node.add_theme_constant_override("margin_right", r)
	node.add_theme_constant_override("margin_bottom", b)


func _panel_style(bg: Color, border: Color, radius: int, bw: int, pad: int) -> StyleBoxFlat:
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
