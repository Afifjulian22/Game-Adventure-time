extends Control

## Panel pengaturan suara yang dipakai di menu utama dan menu pause.
## Dua kelompok suara:
##   - MUSIK LATAR : bus "Music"
##   - EFEK SUARA  : bus "SFX"
## Perubahan langsung terdengar dan disimpan otomatis oleh autoload Settings.

signal closed

const C_GOLD := Color(1.0, 0.84, 0.5)
const C_TEXT := Color(1.0, 0.97, 0.92)
const C_DIM := Color(1.0, 1.0, 1.0, 0.62)
const C_PANEL := Color(0.05, 0.055, 0.08, 0.97)
const C_BTN := Color(0.1, 0.11, 0.15, 0.92)
const C_BTN_HOVER := Color(0.17, 0.18, 0.24, 0.96)

var _settings: Node
var _music_slider: HSlider
var _sfx_slider: HSlider
var _music_value: Label
var _sfx_value: Label


func _ready() -> void:
	# Tetap bisa dipakai saat SceneTree di-pause (dari menu pause).
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_settings = get_node("/root/Settings")
	_build_ui()


func open() -> void:
	_sync_sliders()
	visible = true
	move_to_front()
	if _music_slider != null:
		_music_slider.grab_focus()


func close() -> void:
	if not visible:
		return
	_settings.save_settings()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ==================================================================== UI
func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL, Color(1.0, 0.8, 0.42, 0.4), 24))
	center.add_child(panel)

	var margin := MarginContainer.new()
	_margins(margin, 48, 34, 48, 34)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	margin.add_child(v)

	var title := _label("PENGATURAN", 40, C_GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06, 1))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var sub := _label("Atur volume suara permainan", 15, C_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)

	var music := _add_volume_row(v, "MUSIK LATAR")
	_music_slider = music[0]
	_music_value = music[1]
	_music_slider.value_changed.connect(_on_music_changed)

	var sfx := _add_volume_row(v, "EFEK SUARA")
	_sfx_slider = sfx[0]
	_sfx_value = sfx[1]
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	var note := _label("Musik = lagu latar. Efek = suara koin, tombol, dan lainnya.", 13, C_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)

	var back := _button("KEMBALI")
	back.pressed.connect(close)
	v.add_child(back)


func _add_volume_row(parent: VBoxContainer, text: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)

	var name_label := _label(text, 20, C_TEXT)
	name_label.custom_minimum_size = Vector2(200, 0)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(0, 34)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := _label("100%", 20, C_TEXT)
	value_label.custom_minimum_size = Vector2(78, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_label)

	return [slider, value_label]


func _sync_sliders() -> void:
	if _music_slider == null or _settings == null:
		return
	var music := roundf(float(_settings.music_volume) * 100.0)
	var sfx := roundf(float(_settings.sfx_volume) * 100.0)
	_music_slider.set_value_no_signal(music)
	_music_value.text = "%d%%" % int(music)
	_sfx_slider.set_value_no_signal(sfx)
	_sfx_value.text = "%d%%" % int(sfx)


# ==================================================================== aksi
func _on_music_changed(value: float) -> void:
	_music_value.text = "%d%%" % int(roundf(value))
	_settings.set_music_volume(value / 100.0)


func _on_sfx_changed(value: float) -> void:
	_sfx_value.text = "%d%%" % int(roundf(value))
	_settings.set_sfx_volume(value / 100.0)


# ==================================================================== util
func _button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_stylebox_override("normal", _panel_style(C_BTN, Color(1.0, 0.8, 0.42, 0.5), 14))
	btn.add_theme_stylebox_override("hover", _panel_style(C_BTN_HOVER, C_GOLD, 14))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.06, 0.07, 0.1, 1), C_GOLD, 14))
	btn.add_theme_stylebox_override("focus", _panel_style(C_BTN_HOVER, C_GOLD, 14))
	btn.add_theme_color_override("font_color", C_TEXT)
	return btn


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _margins(node: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	node.add_theme_constant_override("margin_left", left)
	node.add_theme_constant_override("margin_top", top)
	node.add_theme_constant_override("margin_right", right)
	node.add_theme_constant_override("margin_bottom", bottom)


func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	return sb
