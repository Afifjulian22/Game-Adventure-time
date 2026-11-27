extends Control

## Menu utama: main sendirian atau masuk lobby multiplayer.

@onready var status: Label = %Status
@onready var host_info: Label = %HostInfo

var _net: Node
var _settings_panel: Control


func _ready() -> void:
	_net = get_node("/root/Net")
	_net.status_changed.connect(_on_status)
	host_info.text = "IP perangkat ini: " + str(_net.local_ip_text())
	status.text = "Pilih MAIN SENDIRIAN atau MULTIPLAYER untuk bermain berdua."
	_setup_settings_panel()
	_handle_cmdline()


# Panel pengaturan dibuat lewat kode supaya tampil di atas panel menu.
func _setup_settings_panel() -> void:
	var packed := load("res://settings_panel.tscn") as PackedScene
	if packed == null:
		return
	_settings_panel = packed.instantiate()
	add_child(_settings_panel)


# Argumen opsional setelah "--" untuk testing / otomatisasi:
#   --host            langsung buat room
#   --join=IP         langsung join ke host (port default 8910)
#   --join=IP:PORT    join ke host dengan port tertentu
func _handle_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			_net.create_room("Room Test", "Normal", false, "")
		elif arg.begins_with("--join="):
			var target := arg.substr("--join=".length())
			var port := 8910
			if target.contains(":"):
				port = int(target.get_slice(":", 1))
				target = target.get_slice(":", 0)
			_net.join_room(target, "", port)


func _on_status(text: String) -> void:
	status.text = text


func _on_solo_pressed() -> void:
	_open_level_select()


# ------------------------------------------------- pilihan level kesulitan
func _open_level_select() -> void:
	var panel := get_node_or_null("LevelSelect") as Control
	if panel == null:
		# Fallback kalau panel tidak ada.
		_net.start_solo("Normal")
		return
	panel.visible = true
	panel.move_to_front()
	var first := panel.find_child("Easy", true, false) as Button
	if first != null:
		first.grab_focus()


func _close_level_select() -> void:
	var panel := get_node_or_null("LevelSelect")
	if panel != null:
		panel.visible = false
	var solo := get_node_or_null("Center/Panel/VBox/Solo") as Button
	if solo != null:
		solo.grab_focus()


func _on_level_easy_pressed() -> void:
	_start_solo_level("Mudah")


func _on_level_normal_pressed() -> void:
	_start_solo_level("Normal")


func _on_level_sulit_pressed() -> void:
	_start_solo_level("Sulit")


func _on_level_back_pressed() -> void:
	_close_level_select()


func _start_solo_level(mode: String) -> void:
	_net.start_solo(mode)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var panel := get_node_or_null("LevelSelect")
	if panel != null and panel.visible:
		panel.visible = false
		get_viewport().set_input_as_handled()


func _on_multiplayer_pressed() -> void:
	_net.open_lobby()


func _on_customize_pressed() -> void:
	_net.open_customize()


func _on_settings_pressed() -> void:
	if _settings_panel != null:
		_settings_panel.open()


func _on_exit_pressed() -> void:
	get_tree().quit()
