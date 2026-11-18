extends Control

## Menu utama: main sendirian, jadi host, atau join ke host lewat LAN.

@onready var ip_edit: LineEdit = %IpEdit
@onready var status: Label = %Status
@onready var host_info: Label = %HostInfo

var _net: Node


func _ready() -> void:
	_net = get_node("/root/Net")
	_net.status_changed.connect(_on_status)
	host_info.text = "IP perangkat ini: " + _guess_local_ip()
	status.text = "Pemain 1: tekan HOST GAME.   Pemain 2: isi IP host, lalu tekan JOIN."
	_handle_cmdline()


# Argumen opsional setelah "--" untuk testing / otomatisasi:
#   --host            langsung jadi host
#   --join=IP         langsung join ke host
func _handle_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			_net.host_game()
		elif arg.begins_with("--join="):
			_net.join_game(arg.substr("--join=".length()))


func _on_status(text: String) -> void:
	status.text = text


func _on_solo_pressed() -> void:
	_net.start_solo()


func _on_host_pressed() -> void:
	_net.host_game()


func _on_join_pressed() -> void:
	_net.join_game(ip_edit.text)


func _on_exit_pressed() -> void:
	get_tree().quit()


# Menampilkan alamat LAN perangkat ini supaya bisa diketik di HP kedua.
# Wi-Fi (192.168.x.x) diprioritaskan di depan.
func _guess_local_ip() -> String:
	var wifi: Array[String] = []
	var other: Array[String] = []

	for addr in IP.get_local_addresses():
		if addr.split(".").size() != 4:
			continue
		if addr.begins_with("127.") or addr.begins_with("169.254."):
			continue

		if addr.begins_with("192.168."):
			if not wifi.has(addr):
				wifi.append(addr)
		elif addr.begins_with("10.") or addr.begins_with("172."):
			if not other.has(addr):
				other.append(addr)

	var semua := wifi + other
	if semua.is_empty():
		return "belum terdeteksi"

	return " / ".join(semua.slice(0, 2))
