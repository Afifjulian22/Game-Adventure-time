extends Control

## Menu utama: main sendirian atau masuk lobby multiplayer.

@onready var status: Label = %Status
@onready var host_info: Label = %HostInfo

var _net: Node


func _ready() -> void:
	_net = get_node("/root/Net")
	_net.status_changed.connect(_on_status)
	host_info.text = "IP perangkat ini: " + str(_net.local_ip_text())
	status.text = "Pilih MAIN SENDIRIAN atau MULTIPLAYER untuk bermain berdua."
	_handle_cmdline()


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
	_net.start_solo()


func _on_multiplayer_pressed() -> void:
	_net.open_lobby()


func _on_exit_pressed() -> void:
	get_tree().quit()
