extends CanvasLayer

## Menu pause.
## Esc / P  -> buka atau tutup pause.
## Tombol "LANJUTKAN" -> lanjut main.
## Tombol "PENGATURAN SUARA" -> panel volume musik & efek.
## Tombol "MAIN MENU" -> kembali ke halaman utama (menu.tscn).

var _settings_panel: Control


func _ready() -> void:
	# Tetap jalan walaupun SceneTree sedang di-pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_tree().paused = false
	_setup_settings_panel()


func _setup_settings_panel() -> void:
	var packed := load("res://settings_panel.tscn") as PackedScene
	if packed == null:
		return
	_settings_panel = packed.instantiate()
	add_child(_settings_panel)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return

	# Saat panel pengaturan terbuka, Esc ditangani panel itu sendiri.
	if _settings_panel != null and _settings_panel.visible:
		return

	if visible:
		resume()
	else:
		open()

	get_viewport().set_input_as_handled()


func open() -> void:
	if visible:
		return

	if _settings_panel != null:
		_settings_panel.close()
	visible = true
	get_tree().paused = true
	$Root/Center/Panel/VBox/Resume.grab_focus()


func resume() -> void:
	if _settings_panel != null:
		_settings_panel.close()
	visible = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	resume()


func _on_settings_pressed() -> void:
	if _settings_panel != null:
		_settings_panel.open()


func _on_main_menu_pressed() -> void:
	visible = false
	get_tree().paused = false
	var net := get_node_or_null("/root/Net")
	if net != null:
		net.back_to_menu()
	else:
		get_tree().change_scene_to_file("res://menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
