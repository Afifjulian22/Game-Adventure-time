extends Node

## Autoload jaringan sederhana untuk 2 pemain (1 host + 1 client) lewat LAN.
## Host memakai Player 1 (Afif), client memakai Player 2 (Pink Man).

signal status_changed(text: String)

const PORT: int = 8910
const MAX_CLIENTS: int = 1
const MENU_SCENE: String = "res://menu.tscn"
const GAME_SCENE: String = "res://node_2d.tscn"

var role: String = "single"   # "single" | "host" | "client"
var peers: Array[int] = []
var in_game: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_multiplayer() -> bool:
	return role == "host" or role == "client"


func is_host() -> bool:
	return role == "host"


func my_id() -> int:
	return multiplayer.get_unique_id()


# ------------------------------------------------------------------ host / join
func host_game() -> Error:
	reset_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		status_changed.emit("Gagal membuat game (error %d). Tutup instance lain lalu coba lagi." % err)
		return err
	multiplayer.multiplayer_peer = peer
	role = "host"
	status_changed.emit("Menunggu pemain kedua... (port %d)" % PORT)
	return OK


func join_game(ip: String) -> Error:
	reset_peer()
	var target := ip.strip_edges()
	if target.is_empty():
		target = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(target, PORT)
	if err != OK:
		status_changed.emit("Alamat IP tidak valid (error %d)." % err)
		return err
	multiplayer.multiplayer_peer = peer
	role = "client"
	status_changed.emit("Menghubungkan ke %s:%d..." % [target, PORT])
	return OK


# ------------------------------------------------------------------ scene flow
func start_solo() -> void:
	reset_peer()
	in_game = true
	get_tree().change_scene_to_file(GAME_SCENE)


func back_to_menu() -> void:
	reset_peer()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func reset_peer() -> void:
	peers.clear()
	in_game = false
	var old := multiplayer.multiplayer_peer
	if old != null:
		old.close()
	multiplayer.multiplayer_peer = null
	role = "single"


# ------------------------------------------------------------------ callbacks
func _on_peer_connected(id: int) -> void:
	if role != "host":
		return
	if not peers.has(id):
		peers.append(id)

	# Begitu pemain kedua masuk, kedua perangkat langsung pindah ke level.
	status_changed.emit("Pemain 2 terhubung! Memulai permainan...")
	in_game = true
	_start_client_rpc.rpc_id(id)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_peer_disconnected(id: int) -> void:
	peers.erase(id)
	if role != "host":
		return

	if in_game:
		# Ditunda supaya aman menutup peer di luar callback jaringan.
		_back_to_menu_deferred.call_deferred()
	else:
		status_changed.emit("Pemain 2 keluar. Menunggu pemain lain...")


func _back_to_menu_deferred() -> void:
	back_to_menu()


func _on_connected_to_server() -> void:
	status_changed.emit("Terhubung! Menunggu host memulai permainan...")


func _on_connection_failed() -> void:
	reset_peer()
	status_changed.emit("Gagal terhubung. Cek IP host dan pastikan kedua HP di Wi-Fi yang sama.")


func _on_server_disconnected() -> void:
	var was_playing := in_game
	reset_peer()
	if was_playing:
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		status_changed.emit("Host terputus.")


@rpc("authority", "call_remote", "reliable")
func _start_client_rpc() -> void:
	in_game = true
	get_tree().change_scene_to_file(GAME_SCENE)
