extends Control

## Lobby multiplayer: Quick Join, Buat Room, Gabung Room,
## plus daftar room LAN dengan keterangan mode, jumlah pemain,
## dan status UMUM / PRIVAT.

const C_GOLD := Color(1.0, 0.84, 0.5)
const C_ORANGE := Color(1.0, 0.62, 0.35)
const C_BLUE := Color(0.55, 0.8, 1.0)
const C_TEXT := Color(1.0, 0.96, 0.9)
const C_DIM := Color(1.0, 1.0, 1.0, 0.58)
const C_GREEN := Color(0.42, 0.92, 0.55)
const C_RED := Color(1.0, 0.45, 0.4)
const C_PANEL := Color(0.04, 0.05, 0.075, 0.74)
const C_PANEL_SOFT := Color(0.06, 0.07, 0.1, 0.96)
const C_BORDER := Color(1.0, 1.0, 1.0, 0.16)
const C_BTN := Color(0.09, 0.1, 0.14, 0.94)
const C_BTN_HOVER := Color(0.16, 0.17, 0.23, 0.98)

const MODES := ["Mudah", "Normal", "Sulit"]
const SCAN_INTERVAL_MS := 1600
const JOIN_TIMEOUT_MS := 8000

var _net: Node

var _rooms: Array = []
var _next_scan: int = 0
var _join_deadline: int = 0
var _pending_room: Dictionary = {}

# --- node yang dibuat dari kode
var _overlay: Control
var _dialogs: Array[Control] = []

var _dlg_create: PanelContainer
var _dlg_ip: PanelContainer
var _dlg_pass: PanelContainer
var _dlg_host: PanelContainer
var _dlg_join: PanelContainer

var _room_list: VBoxContainer
var _online_label: Label
var _rooms_label: Label
var _status_label: Label

# form buat room
var _create_name: LineEdit
var _create_mode: OptionButton
var _mode_hint: Label
var _create_code: LineEdit
var _create_code_row: VBoxContainer
var _create_error: Label
var _vis_public: Button
var _vis_private: Button

# form gabung lewat IP
var _ip_edit: LineEdit
var _ip_port: LineEdit
var _ip_code: LineEdit
var _ip_error: Label

# form kode room privat
var _pass_name: Label
var _pass_edit: LineEdit
var _pass_error: Label

# panel host menunggu
var _host_name: Label
var _host_meta: Label
var _host_ip: Label
var _host_code: Label

# panel menghubungkan
var _join_info: Label


func _ready() -> void:
	_net = get_node("/root/Net")
	_build_ui()
	_net.status_changed.connect(_on_status)
	_net.rooms_changed.connect(_on_rooms)
	_net.join_failed.connect(_on_join_failed)
	_set_status("Mencari room di Wi-Fi ini...", C_DIM)
	_net.scan_rooms(0.7)


func _exit_tree() -> void:
	if _net != null:
		_net.stop_scanning()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _net.role == "single" and now >= _next_scan:
		_next_scan = now + SCAN_INTERVAL_MS
		_net.scan_rooms(0.6)

	if _join_deadline > 0 and now > _join_deadline:
		_join_deadline = 0
		_net.reset_peer()
		_hide_dialog()
		_set_status("Tidak bisa terhubung. Cek IP host / Wi-Fi lalu coba lagi.", C_RED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _overlay != null and _overlay.visible:
			_hide_dialog()
			if _join_deadline > 0:
				_join_deadline = 0
				_net.reset_peer()
		else:
			_on_back_pressed()
		get_viewport().set_input_as_handled()


# ==================================================================== UI
func _build_ui() -> void:
	var vid := VideoStreamPlayer.new()
	vid.name = "Video"
	vid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vid.expand = true
	vid.autoplay = true
	vid.stream = load("res://Free/Background/village.ogv")
	add_child(vid)

	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.52)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins(margin, 30, 26, 30, 26)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)
	row.add_child(_build_left())
	row.add_child(_build_right())

	_build_overlay()
	_show_dialog(null)


func _build_left() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL))

	var m := MarginContainer.new()
	_margins(m, 26, 24, 26, 22)
	panel.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)

	v.add_child(_label("MULTIPLAYER", 40, C_GOLD, true))
	v.add_child(_label("Main berdua di Wi-Fi yang sama", 15, C_DIM))
	v.add_child(_spacer(12))

	v.add_child(_action("QUICK JOIN", "Langsung masuk room umum pertama", C_GREEN, _on_quick_pressed))
	v.add_child(_action("BUAT ROOM", "Buka room baru lalu tunggu teman", C_GOLD, _on_create_pressed))
	v.add_child(_action("GABUNG ROOM", "Pilih room di kanan atau ketik IP host", C_BLUE, _on_join_pressed))
	v.add_child(_spacer(8))
	v.add_child(_hline())
	v.add_child(_spacer(6))

	var row_online := HBoxContainer.new()
	row_online.add_theme_constant_override("separation", 10)
	row_online.add_child(_dot(C_GREEN))
	_online_label = _label("Online: 0", 16, C_TEXT)
	row_online.add_child(_online_label)
	v.add_child(row_online)

	var row_rooms := HBoxContainer.new()
	row_rooms.add_theme_constant_override("separation", 10)
	row_rooms.add_child(_dot(C_GREEN))
	_rooms_label = _label("Room aktif: 0", 16, C_TEXT)
	row_rooms.add_child(_rooms_label)
	v.add_child(row_rooms)

	v.add_child(_spacer(6))
	var ip_lbl := _label("IP perangkat ini: " + str(_net.local_ip_text()), 13, C_DIM)
	ip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ip_lbl)

	v.add_child(_spacer(1, true))

	_status_label = _label("", 13, C_DIM)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 38)
	v.add_child(_status_label)

	var back := _small_button("KEMBALI")
	back.pressed.connect(_on_back_pressed)
	v.add_child(back)

	return panel


func _build_right() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL))

	var m := MarginContainer.new()
	_margins(m, 24, 20, 24, 20)
	panel.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)

	var title := _label("ROOM AKTIF", 30, C_GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var refresh := _small_button("SEGARKAN")
	refresh.pressed.connect(_refresh_scan)
	head.add_child(refresh)

	v.add_child(_label("Room yang terlihat di Wi-Fi ini", 13, C_DIM))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_room_list = VBoxContainer.new()
	_room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_room_list)

	_rebuild_rooms()
	return panel


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.66)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	_dlg_create = _build_create_dialog()
	_dlg_ip = _build_ip_dialog()
	_dlg_pass = _build_pass_dialog()
	_dlg_host = _build_host_dialog()
	_dlg_join = _build_join_dialog()

	for d in [_dlg_create, _dlg_ip, _dlg_pass, _dlg_host, _dlg_join]:
		d.visible = false
		center.add_child(d)
		_dialogs.append(d)


func _build_create_dialog() -> PanelContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_label("BUAT ROOM", 32, C_GOLD, true))
	v.add_child(_label("Room tampil di daftar pemain lain di Wi-Fi ini.", 13, C_DIM))

	v.add_child(_field("NAMA ROOM"))
	_create_name = _line_edit("Contoh: Room Afif")
	v.add_child(_create_name)

	v.add_child(_field("MODE PERMAINAN"))
	_create_mode = OptionButton.new()
	for m in MODES:
		_create_mode.add_item(m)
	_create_mode.custom_minimum_size = Vector2(0, 50)
	_create_mode.add_theme_font_size_override("font_size", 18)
	_create_mode.item_selected.connect(_on_mode_selected)
	v.add_child(_create_mode)

	# Keterangan singkat isi tiap mode, berubah saat mode diganti.
	_mode_hint = _label("", 12, C_DIM)
	_mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_mode_hint)
	_create_mode.selected = MODES.find("Normal")
	_update_mode_hint()

	v.add_child(_field("VISIBILITAS"))
	var vis := HBoxContainer.new()
	vis.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()

	_vis_public = Button.new()
	_vis_public.text = "UMUM"
	_vis_public.toggle_mode = true
	_vis_public.button_group = group
	_vis_public.button_pressed = true
	_vis_public.custom_minimum_size = Vector2(0, 50)
	_vis_public.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_toggle(_vis_public, C_GREEN)
	vis.add_child(_vis_public)

	_vis_private = Button.new()
	_vis_private.text = "PRIVAT"
	_vis_private.toggle_mode = true
	_vis_private.button_group = group
	_vis_private.custom_minimum_size = Vector2(0, 50)
	_vis_private.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_toggle(_vis_private, C_ORANGE)
	_vis_private.toggled.connect(_on_vis_toggled)
	vis.add_child(_vis_private)
	v.add_child(vis)

	_create_code_row = VBoxContainer.new()
	_create_code_row.add_theme_constant_override("separation", 10)
	_create_code_row.add_child(_field("KODE ROOM (BAGIKAN KE TEMAN)"))
	_create_code = _line_edit("contoh: 1234")
	_create_code.max_length = 8
	_create_code.text = _random_code()
	_create_code_row.add_child(_create_code)
	_create_code_row.visible = false
	v.add_child(_create_code_row)

	_create_error = _label("", 13, C_RED)
	v.add_child(_create_error)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	var cancel := _small_button("BATAL")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_hide_dialog)
	actions.add_child(cancel)
	var ok := _small_button("BUAT ROOM", C_GOLD)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_on_create_confirm)
	actions.add_child(ok)
	v.add_child(actions)

	return _wrap_dialog(v, 600)


func _build_ip_dialog() -> PanelContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_label("GABUNG ROOM", 32, C_GOLD, true))
	v.add_child(_label("Ketik IP host. Kode room hanya untuk room privat.", 13, C_DIM))

	v.add_child(_field("IP HOST"))
	_ip_edit = _line_edit("192.168.1.10")
	v.add_child(_ip_edit)

	v.add_child(_field("PORT (BIARKAN 8910 JIKA TIDAK YAKIN)"))
	_ip_port = _line_edit("8910")
	_ip_port.max_length = 5
	_ip_port.text = "8910"
	v.add_child(_ip_port)

	v.add_child(_field("KODE ROOM (OPSIONAL)"))
	_ip_code = _line_edit("kosongkan jika room umum")
	v.add_child(_ip_code)

	_ip_error = _label("", 13, C_RED)
	v.add_child(_ip_error)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	var cancel := _small_button("BATAL")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_hide_dialog)
	actions.add_child(cancel)
	var ok := _small_button("GABUNG", C_GOLD)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_on_ip_confirm)
	actions.add_child(ok)
	v.add_child(actions)

	return _wrap_dialog(v, 580)


func _build_pass_dialog() -> PanelContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_label("ROOM PRIVAT", 32, C_ORANGE, true))
	_pass_name = _label("", 20, C_TEXT)
	v.add_child(_pass_name)
	v.add_child(_label("Masukkan kode room untuk masuk.", 13, C_DIM))

	v.add_child(_field("KODE ROOM"))
	_pass_edit = _line_edit("kode room")
	_pass_edit.max_length = 8
	v.add_child(_pass_edit)

	_pass_error = _label("", 13, C_RED)
	v.add_child(_pass_error)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	var cancel := _small_button("BATAL")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_hide_dialog)
	actions.add_child(cancel)
	var ok := _small_button("MASUK", C_GOLD)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_on_pass_confirm)
	actions.add_child(ok)
	v.add_child(actions)

	return _wrap_dialog(v, 540)


func _build_host_dialog() -> PanelContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_label("ROOM DIBUAT", 32, C_GOLD, true))

	_host_name = _label("", 26, C_TEXT)
	_host_meta = _label("", 15, C_DIM)
	_host_ip = _label("", 15, C_TEXT)
	_host_code = _label("", 15, C_ORANGE)
	v.add_child(_host_name)
	v.add_child(_host_meta)
	v.add_child(_spacer(4))
	v.add_child(_host_ip)
	v.add_child(_host_code)

	v.add_child(_spacer(6))
	v.add_child(_label("Menunggu pemain kedua bergabung...", 17, C_GREEN))
	v.add_child(_label("Minta teman memilih room ini di daftar, atau mengetik IP di atas.", 13, C_DIM))

	var close := _small_button("TUTUP ROOM", C_ORANGE)
	close.pressed.connect(_on_close_room)
	v.add_child(close)

	return _wrap_dialog(v, 620)


func _build_join_dialog() -> PanelContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_label("MENGHUBUNGKAN", 30, C_GOLD, true))
	_join_info = _label("", 16, C_TEXT)
	_join_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_join_info)
	v.add_child(_label("Pastikan host masih membuka room dan kedua perangkat ada di Wi-Fi yang sama.", 13, C_DIM))

	var cancel := _small_button("BATAL")
	cancel.pressed.connect(_on_cancel_join)
	v.add_child(cancel)

	return _wrap_dialog(v, 560)


# ------------------------------------------------------------------ builder
func _wrap_dialog(content: Control, min_w: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_w, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL_SOFT, Color(1, 1, 1, 0.22), 26, 2, 28))
	panel.add_child(content)
	return panel


func _action(title: String, hint: String, accent: Color, callback: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var btn := Button.new()
	btn.text = title
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.custom_minimum_size = Vector2(0, 68)
	btn.add_theme_font_size_override("font_size", 24)
	_style_button(btn, accent)
	btn.pressed.connect(callback)
	box.add_child(btn)

	var h := _label(hint, 12, C_DIM)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	return box


func _small_button(text: String, accent: Color = Color(1, 1, 1, 0.35)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 50)
	btn.add_theme_font_size_override("font_size", 17)
	_style_button(btn, accent)
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


func _field(text: String) -> Label:
	var l := _label(text, 12, C_DIM)
	return l


func _line_edit(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 50)
	e.add_theme_font_size_override("font_size", 18)
	e.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35))
	e.add_theme_stylebox_override("normal", _panel_style(Color(0.08, 0.09, 0.13, 1), C_BORDER, 12, 1, 14))
	e.add_theme_stylebox_override("focus", _panel_style(Color(0.1, 0.11, 0.16, 1), C_GOLD, 12, 2, 14))
	return e


func _dot(color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(10, 10)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _tag(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_label(text, 12, color))
	return p


func _hline() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.12)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _spacer(h: int, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _margins(node: Control, l: int, t: int, r: int, b: int) -> void:
	node.add_theme_constant_override("margin_left", l)
	node.add_theme_constant_override("margin_top", t)
	node.add_theme_constant_override("margin_right", r)
	node.add_theme_constant_override("margin_bottom", b)


func _panel_style(bg: Color, border: Color = C_BORDER, radius: int = 22, bw: int = 2, pad: int = 18) -> StyleBoxFlat:
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


func _style_button(btn: Button, accent: Color) -> void:
	btn.add_theme_stylebox_override("normal", _panel_style(C_BTN, Color(accent.r, accent.g, accent.b, 0.45), 16, 2, 16))
	btn.add_theme_stylebox_override("hover", _panel_style(C_BTN_HOVER, accent, 16, 2, 16))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.05, 0.06, 0.09, 1), accent, 16, 2, 16))
	btn.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 16, 0, 16))
	btn.add_theme_stylebox_override("disabled", _panel_style(Color(0.06, 0.065, 0.09, 0.8), Color(1, 1, 1, 0.08), 16, 2, 16))
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", accent)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.32))


## Tombol pilihan (UMUM / PRIVAT): saat aktif, latarnya diberi warna aksen
## supaya jelas mana yang sedang dipilih.
func _style_toggle(btn: Button, accent: Color) -> void:
	_style_button(btn, accent)
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(accent.r, accent.g, accent.b, 0.26), accent, 16, 2, 16))
	btn.add_theme_stylebox_override("hover_pressed", _panel_style(Color(accent.r, accent.g, accent.b, 0.34), accent, 16, 2, 16))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_pressed_color", Color(1, 1, 1, 1))


# ==================================================================== daftar room
func _rebuild_rooms() -> void:
	for c in _room_list.get_children():
		_room_list.remove_child(c)
		c.queue_free()

	if _rooms.is_empty():
		var empty := _label("Belum ada room.\nTekan BUAT ROOM untuk membuka room pertama.", 16, C_DIM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(0, 120)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_room_list.add_child(empty)
		return

	for r in _rooms:
		_room_list.add_child(_make_room_row(r))


func _make_room_row(r: Dictionary) -> Button:
	var cur := int(r["cur"])
	var mx := int(r["max"])
	var full := cur >= mx
	var is_private := bool(r["private"])

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 82)
	btn.disabled = full
	_style_button(btn, C_ORANGE if is_private else C_GOLD)
	btn.pressed.connect(_on_room_row_pressed.bind(r))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins(pad, 18, 8, 18, 8)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(pad)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(h)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)

	var nm := _label(String(r["name"]), 22, C_TEXT)
	v.add_child(nm)

	var addr := String(r["ip"])
	var row_port := int(r.get("port", 8910))
	if row_port != 8910:
		addr += ":%d" % row_port
	var sub := _label("%s  •  %d/%d pemain  •  %s" % [String(r["mode"]), cur, mx, addr], 13, C_DIM)
	v.add_child(sub)

	h.add_child(_tag("PRIVAT" if is_private else "UMUM", C_ORANGE if is_private else C_GREEN))

	var state := _label("PENUH" if full else "GABUNG", 16, C_DIM if full else C_GOLD)
	h.add_child(state)

	return btn


# ==================================================================== aksi
func _on_room_row_pressed(r: Dictionary) -> void:
	_try_join(r)


func _on_quick_pressed() -> void:
	_set_status("Mencari room umum...", C_DIM)
	_net.scan_rooms(0.8)
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return

	var best: Dictionary = {}
	for r in _rooms:
		if bool(r["private"]):
			continue
		if int(r["cur"]) >= int(r["max"]):
			continue
		if best.is_empty() or int(r["cur"]) > int(best["cur"]):
			best = r

	if best.is_empty():
		_set_status("Tidak ada room umum yang kosong. Buat room sendiri atau gabung lewat IP.", C_RED)
		return
	_try_join(best)


func _on_create_pressed() -> void:
	_create_error.text = ""
	if _create_name.text.strip_edges().is_empty() or _create_name.text.begins_with("Room "):
		_create_name.text = "Room " + _net.device_name()
	_show_dialog(_dlg_create)
	_create_name.grab_focus()


func _on_create_confirm() -> void:
	var nm := _create_name.text.strip_edges()
	if nm.is_empty():
		_create_error.text = "Nama room belum diisi."
		return

	var priv: bool = _vis_private.button_pressed
	var code := _create_code.text.strip_edges()
	if priv and code.length() < 3:
		_create_error.text = "Kode room minimal 3 karakter."
		return

	var err: int = _net.create_room(nm, MODES[_create_mode.selected], priv, code)
	if err != OK:
		_create_error.text = "Gagal membuat room: semua port 8910-8917 dipakai. Tutup aplikasi lain yang memakai port tersebut."
		return

	_refresh_host_dialog()
	_show_dialog(_dlg_host)


func _on_vis_toggled(on: bool) -> void:
	_create_code_row.visible = on


## Keterangan mode: menjelaskan efek kesulitan ke pemain.
func _on_mode_selected(_index: int) -> void:
	_update_mode_hint()


func _update_mode_hint() -> void:
	if _mode_hint == null or _create_mode == null:
		return
	var mode: String = MODES[_create_mode.selected]
	match mode:
		"Mudah":
			_mode_hint.text = "Rintangan sedikit, trap lambat. Cocok untuk santai & pemain baru."
		"Sulit":
			_mode_hint.text = "Rintangan paling banyak, trap sangat cepat, platform cepat jatuh."
		_:
			_mode_hint.text = "Rintangan lebih banyak, trap lebih cepat, dan level lebih sulit diselesaikan."


func _on_close_room() -> void:
	_net.close_room()
	_hide_dialog()
	_set_status("Room ditutup.", C_DIM)
	_net.scan_rooms(0.5)


func _on_join_pressed() -> void:
	_ip_error.text = ""
	if _ip_edit.text.strip_edges().is_empty() and not _rooms.is_empty():
		_ip_edit.text = String(_rooms[0]["ip"])
		_ip_port.text = str(int(_rooms[0].get("port", 8910)))
	_show_dialog(_dlg_ip)
	_ip_edit.grab_focus()


func _on_ip_confirm() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip.is_empty():
		_ip_error.text = "IP host belum diisi."
		return
	var port := int(_ip_port.text.strip_edges())
	if port <= 0:
		port = 8910
	_connect_to(ip, _ip_code.text, port)


func _on_pass_confirm() -> void:
	var code := _pass_edit.text.strip_edges()
	if code.is_empty():
		_pass_error.text = "Masukkan kode room."
		return
	_connect_to(String(_pending_room.get("ip", "")), code, int(_pending_room.get("port", 8910)))


func _try_join(r: Dictionary) -> void:
	if int(r["cur"]) >= int(r["max"]):
		_set_status("Room sudah penuh.", C_RED)
		return
	if bool(r["private"]):
		_pending_room = r
		_pass_name.text = String(r["name"])
		_pass_error.text = ""
		_pass_edit.text = ""
		_show_dialog(_dlg_pass)
		_pass_edit.grab_focus()
		return
	_connect_to(String(r["ip"]), "", int(r.get("port", 8910)))


func _connect_to(ip: String, code: String, port: int = 8910) -> void:
	if ip.strip_edges().is_empty():
		_set_status("IP host tidak diketahui. Ketik manual lewat GABUNG ROOM.", C_RED)
		return
	var err: int = _net.join_room(ip, code, port)
	if err != OK:
		_set_status("Gagal menghubungkan ke %s:%d." % [ip, port], C_RED)
		return
	_join_info.text = "Menghubungkan ke %s:%d..." % [ip, port]
	_join_deadline = Time.get_ticks_msec() + JOIN_TIMEOUT_MS
	_show_dialog(_dlg_join)


func _on_cancel_join() -> void:
	_join_deadline = 0
	_net.reset_peer()
	_hide_dialog()
	_set_status("Dibatalkan.", C_DIM)


func _on_back_pressed() -> void:
	_net.stop_scanning()
	_net.back_to_menu()


func _refresh_scan() -> void:
	_next_scan = Time.get_ticks_msec() + SCAN_INTERVAL_MS
	_net.scan_rooms(0.7)
	_set_status("Menyegarkan daftar room...", C_DIM)


# ==================================================================== event net
func _on_status(text: String) -> void:
	_set_status(text, C_TEXT)


func _on_rooms(list: Array) -> void:
	_rooms = list
	_rebuild_rooms()

	var online := 0
	for r in list:
		online += int(r["cur"])
	_online_label.text = "Online: %d" % online
	_rooms_label.text = "Room aktif: %d" % list.size()


func _on_join_failed(reason: String) -> void:
	_join_deadline = 0
	_hide_dialog()
	_set_status(reason, C_RED)


# ==================================================================== util
func _show_dialog(d: Control) -> void:
	for x in _dialogs:
		x.visible = (x == d)
	_overlay.visible = d != null


func _hide_dialog() -> void:
	_show_dialog(null)
	_pending_room = {}


func _set_status(text: String, color: Color) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _refresh_host_dialog() -> void:
	_host_name.text = str(_net.room_name)
	_host_meta.text = "%s  •  1/%d pemain  •  %s" % [
		str(_net.room_mode), int(_net.room_max),
		"PRIVAT" if bool(_net.room_private) else "UMUM",
	]
	_host_ip.text = "IP host: " + str(_net.local_ip_text()) + "  •  port " + str(int(_net.game_port))
	_host_code.visible = bool(_net.room_private)
	_host_code.text = "Kode room: " + str(_net.room_code)


func _random_code() -> String:
	return "%04d" % (randi() % 10000)
