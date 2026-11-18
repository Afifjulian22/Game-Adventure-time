extends Node

@onready var label: Label = %Label
@onready var label_menang: Label = %Winner
@onready var panel_menang: Panel = %WinPanel

var points: int = 0

# Path koin yang sudah diambil, supaya RPC yang datang terlambat / dobel
# tidak menambah poin dua kali.
var _taken_coins: Dictionary = {}


func add_point() -> void:
	points += 1
	label.text = "Poin : " + str(points)


func tampilkan_kemenangan() -> void:
	panel_menang.show()
	label_menang.text = "Selamat! Total point kamu: " + str(points)


# ------------------------------------------------------------------ koin
# Dipanggil coin.gd saat disentuh pemain lokal. Path koin dipakai sebagai
# identitas karena node koin bisa sudah terhapus di perangkat lain.
func request_coin(coin: Node) -> void:
	var path := String(coin.get_path())
	if _taken_coins.has(path):
		return

	var net := get_node_or_null("/root/Net")
	if net != null and net.is_multiplayer():
		_take_coin.rpc(path)
	else:
		_take_coin(path)


@rpc("any_peer", "call_local", "reliable")
func _take_coin(path: String) -> void:
	if _taken_coins.has(path):
		return
	_taken_coins[path] = true
	add_point()

	var coin := get_node_or_null(NodePath(path))
	if coin != null:
		coin.queue_free()


# ------------------------------------------------------------------ garis akhir
func _on_end_point_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("is_local_player") and not body.is_local_player():
		return

	var net := get_node_or_null("/root/Net")
	if net != null and net.is_multiplayer():
		_rpc_win.rpc()
	else:
		tampilkan_kemenangan()


@rpc("any_peer", "call_local", "reliable")
func _rpc_win() -> void:
	tampilkan_kemenangan()
