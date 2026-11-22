extends Node

## Jaringan LAN untuk 2 pemain + lobby room (buat / gabung / quick join).
## Host memakai Player 1 (Afif), client memakai Player 2 (Pink Man).
##
## Daftar room didapat lewat discovery UDP di port 8911:
## client mem-broadcast "ESC_TOGETHER_V1", host membalas info room.

signal status_changed(text: String)
signal rooms_changed(rooms: Array)
signal join_failed(reason: String)

const PORT: int = 8910
const PORT_TRIES: int = 8          # host mencoba 8910..8917
const MAX_CLIENTS: int = 1
const MENU_SCENE: String = "res://menu.tscn"
const LOBBY_SCENE: String = "res://lobby.tscn"
const GAME_SCENE: String = "res://node_2d.tscn"

const DISCOVERY_PORT: int = 8911
const DISCOVERY_TRIES: int = 8     # host menjawab di 8911..8918
const DISCOVERY_MAGIC: String = "ESC_TOGETHER_V1"
const ROOM_TTL_MS: int = 4000

var role: String = "single"   # "single" | "host" | "client"
var peers: Array[int] = []
var in_game: bool = false

# Info room saat jadi host, atau kode yang dipakai saat join (client).
var room_name: String = ""
var room_mode: String = "Normal"
var room_max: int = 2
var room_private: bool = false
var room_code: String = ""
var game_port: int = PORT          # port ENet yang dipakai host
var discovery_port: int = DISCOVERY_PORT

var _responder: PacketPeerUDP = null
var _scanner: PacketPeerUDP = null
var _found: Dictionary = {}          # key -> { info, ip, seen }
var _scan_active: bool = false
var _scan_until_ms: int = 0
var _rejecting: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(_delta: float) -> void:
	if _responder != null:
		_poll_responder()
	if _scanner != null:
		_poll_scanner()
	if _scan_active and Time.get_ticks_msec() >= _scan_until_ms:
		_scan_active = false
		_emit_rooms()
	if _prune_rooms():
		_emit_rooms()


func is_multiplayer() -> bool:
	return role == "host" or role == "client"


func is_host() -> bool:
	return role == "host"


func my_id() -> int:
	return multiplayer.get_unique_id()


func is_private_room() -> bool:
	return room_private


func player_count() -> int:
	return peers.size() + 1


# ------------------------------------------------------------------ host / join
func host_game() -> Error:
	reset_peer()
	var last_err: int = ERR_CANT_CREATE
	# Satu perangkat bisa punya beberapa instance untuk uji coba,
	# jadi host mencari port kosong mulai dari PORT.
	for i in PORT_TRIES:
		var candidate := PORT + i
		var peer := ENetMultiplayerPeer.new()
		last_err = peer.create_server(candidate, MAX_CLIENTS)
		if last_err == OK:
			multiplayer.multiplayer_peer = peer
			game_port = candidate
			role = "host"
			status_changed.emit("Menunggu pemain kedua... (port %d)" % game_port)
			return OK
	status_changed.emit("Gagal membuat room: port %d-%d sedang dipakai aplikasi lain." % [PORT, PORT + PORT_TRIES - 1])
	return last_err


## Membuat room sekaligus mengaktifkan balasan discovery.
func create_room(p_name: String, p_mode: String, p_private: bool, p_code: String) -> Error:
	var err := host_game()
	if err != OK:
		return err
	room_name = p_name.strip_edges()
	if room_name.is_empty():
		room_name = "Room " + _device_name()
	room_mode = p_mode
	room_private = p_private
	room_code = p_code.strip_edges() if p_private else ""
	room_max = 2
	_start_responder()
	status_changed.emit("Room \"%s\" dibuat. Menunggu pemain kedua... (port %d)" % [room_name, game_port])
	return OK


func close_room() -> void:
	reset_peer()
	status_changed.emit("Room ditutup.")


func join_game(ip: String, code: String = "", p_port: int = 0) -> Error:
	reset_peer()
	# Kode disimpan SETELAH reset_peer(), karena reset_peer() mengosongkannya.
	room_code = code.strip_edges()
	var target := ip.strip_edges()
	if target.is_empty():
		target = "127.0.0.1"
	var port: int = p_port if p_port > 0 else PORT
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(target, port)
	if err != OK:
		status_changed.emit("Alamat IP tidak valid (error %d)." % err)
		join_failed.emit("Alamat IP tidak valid.")
		return err
	multiplayer.multiplayer_peer = peer
	role = "client"
	status_changed.emit("Menghubungkan ke %s:%d..." % [target, port])
	return OK


## Join ke room hasil discovery (atau IP manual).
func join_room(ip: String, code: String = "", p_port: int = 0) -> Error:
	return join_game(ip, code, p_port)


# ------------------------------------------------------------------ scene flow
func start_solo() -> void:
	reset_peer()
	in_game = true
	get_tree().change_scene_to_file(GAME_SCENE)


func open_lobby() -> void:
	reset_peer()
	get_tree().change_scene_to_file(LOBBY_SCENE)


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
	room_name = ""
	room_mode = "Normal"
	room_private = false
	room_code = ""
	room_max = 2
	game_port = PORT
	discovery_port = DISCOVERY_PORT
	_rejecting = false
	_stop_responder()


# ------------------------------------------------------------------ discovery
func scan_rooms(wait: float = 0.6) -> void:
	if role == "host":
		return
	if _scanner == null:
		var udp := PacketPeerUDP.new()
		if udp.bind(0) != OK:
			return
		udp.set_broadcast_enabled(true)
		_scanner = udp

	var payload := DISCOVERY_MAGIC.to_utf8_buffer()
	var targets: Array[String] = ["255.255.255.255", "127.0.0.1"]
	for addr in IP.get_local_addresses():
		if addr.split(".").size() != 4:
			continue
		if addr.begins_with("127.") or addr.begins_with("169.254."):
			continue
		var subnet := "%s.%s.%s.255" % [addr.get_slice(".", 0), addr.get_slice(".", 1), addr.get_slice(".", 2)]
		if not targets.has(subnet):
			targets.append(subnet)

	# Kirim ke semua port discovery supaya room yang memakai port
	# cadangan (beberapa host di satu perangkat) tetap ketemu.
	for t in targets:
		for i in DISCOVERY_TRIES:
			_scanner.set_dest_address(t, DISCOVERY_PORT + i)
			_scanner.put_packet(payload)

	_scan_active = true
	_scan_until_ms = Time.get_ticks_msec() + int(wait * 1000.0)
	_prune_rooms()


func stop_scanning() -> void:
	_scan_active = false
	if _scanner != null:
		_scanner.close()
		_scanner = null
	_found.clear()


func rooms() -> Array:
	return _room_list()


func _start_responder() -> void:
	_stop_responder()
	for i in DISCOVERY_TRIES:
		var p := DISCOVERY_PORT + i
		var udp := PacketPeerUDP.new()
		if udp.bind(p) != OK:
			continue
		_responder = udp
		discovery_port = p
		return
	push_warning("Port discovery %d-%d tidak bisa dipakai; teman masih bisa join lewat IP." % [DISCOVERY_PORT, DISCOVERY_PORT + DISCOVERY_TRIES - 1])


func _stop_responder() -> void:
	if _responder != null:
		_responder.close()
		_responder = null


func _poll_responder() -> void:
	while _responder.get_available_packet_count() > 0:
		var txt := _responder.get_packet().get_string_from_utf8()
		var ip := _responder.get_packet_ip()
		var port := _responder.get_packet_port()
		if not txt.begins_with(DISCOVERY_MAGIC):
			continue
		_responder.set_dest_address(ip, port)
		_responder.put_packet(JSON.stringify(_room_dict()).to_utf8_buffer())


func _poll_scanner() -> void:
	var changed := false
	while _scanner.get_available_packet_count() > 0:
		var txt := _scanner.get_packet().get_string_from_utf8()
		var ip := _scanner.get_packet_ip()
		var info = JSON.parse_string(txt)
		if typeof(info) != TYPE_DICTIONARY:
			continue
		if String(info.get("magic", "")) != DISCOVERY_MAGIC:
			continue
		var game_port_info := int(info.get("port", PORT))
		# Nama + mode + port permainan membedakan room yang berbeda.
		var key := "%s|%s|%d" % [info.get("name", "Room"), info.get("mode", "Normal"), game_port_info]
		var old: Dictionary = _found.get(key, {})
		var old_ip := String(old.get("ip", ""))
		# Utamakan IP LAN daripada loopback.
		if old_ip.is_empty() or (old_ip.begins_with("127.") and not ip.begins_with("127.")):
			info["ip"] = ip
			_found[key] = {"info": info, "ip": ip, "seen": Time.get_ticks_msec()}
			changed = true
	if changed:
		_emit_rooms()


func _prune_rooms() -> bool:
	var now := Time.get_ticks_msec()
	var changed := false
	for key in _found.keys():
		if now - int(_found[key].get("seen", 0)) > ROOM_TTL_MS:
			_found.erase(key)
			changed = true
	return changed


func _room_list() -> Array:
	var arr: Array = []
	for key in _found.keys():
		var entry: Dictionary = _found[key]
		var info: Dictionary = entry["info"]
		var item := {
			"name": String(info.get("name", "Room")),
			"mode": String(info.get("mode", "Normal")),
			"cur": int(info.get("cur", 1)),
			"max": int(info.get("max", 2)),
			"private": bool(info.get("private", false)),
			"ip": String(entry.get("ip", "")),
			"port": int(info.get("port", PORT)),
		}
		arr.append(item)
	arr.sort_custom(func(a, b): return String(a["name"]).to_lower() < String(b["name"]).to_lower())
	return arr


func _emit_rooms() -> void:
	rooms_changed.emit(_room_list())


func _room_dict() -> Dictionary:
	return {
		"magic": DISCOVERY_MAGIC,
		"name": room_name if not room_name.is_empty() else "Room",
		"mode": room_mode,
		"cur": player_count(),
		"max": room_max,
		"private": room_private,
	}


# ------------------------------------------------------------------ helpers
func local_ip_text() -> String:
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


func _device_name() -> String:
	var n := OS.get_environment("USERNAME")
	if n.is_empty():
		n = OS.get_environment("USER")
	if n.is_empty():
		n = "Pemain"
	return n


func device_name() -> String:
	return _device_name()


# ------------------------------------------------------------------ callbacks
func _on_peer_connected(id: int) -> void:
	if role != "host":
		return
	if not peers.has(id):
		peers.append(id)
	_rejecting = false

	if in_game:
		return

	if room_private:
		status_changed.emit("Pemain terhubung. Menunggu kode room...")
	else:
		_begin_game_with(id)


func _begin_game_with(id: int) -> void:
	if in_game:
		return
	in_game = true
	_stop_responder()
	status_changed.emit("Pemain 2 terhubung! Memulai permainan...")
	_start_client_rpc.rpc_id(id)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_peer_disconnected(id: int) -> void:
	peers.erase(id)
	if role != "host":
		return

	if in_game:
		# Ditunda supaya aman menutup peer di luar callback jaringan.
		_back_to_menu_deferred.call_deferred()
	elif _rejecting:
		_rejecting = false
		status_changed.emit("Kode room salah. Menunggu pemain lain...")
	else:
		status_changed.emit("Pemain 2 keluar. Menunggu pemain lain...")


func _back_to_menu_deferred() -> void:
	back_to_menu()


func _on_connected_to_server() -> void:
	status_changed.emit("Terhubung! Memeriksa room...")
	_submit_code_rpc.rpc_id(1, room_code)


func _on_connection_failed() -> void:
	reset_peer()
	status_changed.emit("Gagal terhubung. Cek IP host dan pastikan kedua HP di Wi-Fi yang sama.")
	join_failed.emit("Tidak bisa terhubung ke host.")


func _on_server_disconnected() -> void:
	var was_playing := in_game
	reset_peer()
	if was_playing:
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		status_changed.emit("Host terputus.")
		join_failed.emit("Host terputus.")


@rpc("authority", "call_remote", "reliable")
func _start_client_rpc() -> void:
	in_game = true
	get_tree().change_scene_to_file(GAME_SCENE)


@rpc("any_peer", "call_remote", "reliable")
func _submit_code_rpc(code: String) -> void:
	if role != "host" or in_game:
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		return
	if room_private and code.strip_edges() != room_code:
		_rejecting = true
		_code_rejected_rpc.rpc_id(id)
		return
	_begin_game_with(id)


@rpc("authority", "call_remote", "reliable")
func _code_rejected_rpc() -> void:
	reset_peer()
	status_changed.emit("Kode room salah. Coba lagi.")
	join_failed.emit("Kode room salah.")


# ------------------------------------------------------------------ restart
# Dipakai saat salah satu pemain kehabisan nyawa: kedua perangkat
# mengulang level dari awal (posisi, nyawa, koin, dan poin ikut reset).
var _restart_pending: bool = false


func restart_level() -> void:
	if _restart_pending:
		return
	if is_multiplayer():
		_restart_level_rpc.rpc()
	else:
		_restart_level_rpc()


@rpc("any_peer", "call_local", "reliable")
func _restart_level_rpc() -> void:
	if _restart_pending:
		return
	_restart_pending = true
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)

	# Beri waktu supaya kiriman RPC dari perangkat lain yang datang
	# hampir bersamaan tidak memicu reload kedua.
	await get_tree().create_timer(1.5).timeout
	_restart_pending = false
