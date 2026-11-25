extends Node2D

## Mengatur siapa yang mengendalikan tiap karakter di level dan menyesuaikan
## tingkat kesulitan rintangan.
## - Single player : hanya Player 1 yang ada.
## - Multiplayer   : host mengendalikan Player 1, client mengendalikan Player 2.
## Skin tiap pemain diambil dari Net (dipilih di menu CUSTOMIZE).

@onready var player1: CharacterBody2D = $player
@onready var player2: CharacterBody2D = $Player2

# --------------------------------------------------------------- kesulitan
## Dipakai saat scene map dibuka langsung (mis. map_easy.tscn / map_normal.tscn).
## Saat bermain dari lobby, nilai ini ditimpa mode room (Net.room_mode) supaya
## kedua perangkat memakai setelan yang sama.
@export_enum("Mudah", "Normal", "Sulit") var difficulty: String = "Normal"
## false = selalu pakai nilai `difficulty` di atas, bukan mode room.
@export var use_room_difficulty: bool = true

## Setelan tiap tingkat kesulitan:
##   speed      : pengali kecepatan rintangan bergerak (gergaji, lift)
##   travel     : pengali jarak jelajah rintangan bergerak
##   fall_speed : pengali kecepatan platform jatuh
##   fall_delay : jeda sebelum platform jatuh (kecil = lebih sulit)
##   extra      : tampilkan ExtraTraps (rintangan tambahan)
##   hard       : tampilkan HardTraps (rintangan paling kejam)
const PRESETS := {
	"Mudah": {
		"speed": 0.78,
		"travel": 0.9,
		"fall_speed": 0.8,
		"fall_delay": 0.5,
		"extra": false,
		"hard": false,
	},
	"Normal": {
		"speed": 1.2,
		"travel": 1.1,
		"fall_speed": 1.3,
		"fall_delay": 0.26,
		"extra": true,
		"hard": false,
	},
	"Sulit": {
		"speed": 1.55,
		"travel": 1.2,
		"fall_speed": 1.6,
		"fall_delay": 0.16,
		"extra": true,
		"hard": true,
	},
}


func _ready() -> void:
	_apply_difficulty()

	var net := get_node_or_null("/root/Net")
	var networked: bool = net != null and net.is_multiplayer()
	var host: bool = net != null and net.is_host()

	if not networked:
		# Main sendirian: pemain kedua tidak diperlukan.
		player2.queue_free()
		player1.setup_player(1, true, 1)
		if net != null:
			player1.apply_skin(String(net.my_skin))
		return

	# Peer id client berbeda-beda (bukan selalu 2), jadi diambil dari Net:
	# - host tahu id client dari daftar peers
	# - client tahu id dirinya sendiri
	var client_peer: int = net.peers[0] if not net.peers.is_empty() else 2
	var my_peer: int = net.my_id()

	if host:
		player1.setup_player(1, true, 1)             # milik host
		player2.setup_player(2, false, client_peer)  # milik client
	else:
		player1.setup_player(1, false, 1)            # milik host
		player2.setup_player(2, true, my_peer)       # milik client ini

	_apply_skins()
	# Skin lawan bisa datang setelah level dimuat (mis. room umum yang
	# langsung mulai); terapkan ulang begitu datanya diterima.
	net.skins_changed.connect(_apply_skins)


func _apply_skins() -> void:
	var net := get_node_or_null("/root/Net")
	if net == null:
		return

	var my_skin := String(net.my_skin)
	var peer_skin := String(net.remote_skin)

	if not net.is_multiplayer():
		player1.apply_skin(my_skin)
		return

	if net.is_host():
		player1.apply_skin(my_skin)
		if not peer_skin.is_empty():
			player2.apply_skin(peer_skin)
	else:
		if not peer_skin.is_empty():
			player1.apply_skin(peer_skin)
		player2.apply_skin(my_skin)


# ================================================================== kesulitan
func _apply_difficulty() -> void:
	difficulty = _resolve_difficulty()
	var preset: Dictionary = PRESETS[difficulty]

	for group_name in ["Traps", "Platforms", "ExtraTraps", "HardTraps"]:
		_scale_traps(get_node_or_null(group_name), preset)

	# Rintangan tambahan hanya ada di Normal & Sulit, rintangan "keras"
	# hanya di Sulit. Node yang tidak dipakai dihapus, bukan cuma
	# disembunyikan, supaya area tetap bisa melukai pemain walau sprite-nya
	# tak terlihat.
	_keep_traps(get_node_or_null("ExtraTraps"), bool(preset["extra"]))
	_keep_traps(get_node_or_null("HardTraps"), bool(preset["hard"]))

	_show_difficulty_label()


func _resolve_difficulty() -> String:
	var mode := difficulty
	if use_room_difficulty:
		var net := get_node_or_null("/root/Net")
		if net != null and not String(net.room_mode).is_empty():
			mode = String(net.room_mode)
	# "Santai" adalah nama lama untuk Mudah (room dari versi sebelumnya).
	match mode.strip_edges().to_lower():
		"mudah", "santai", "easy":
			return "Mudah"
		"sulit", "hard":
			return "Sulit"
		_:
			return "Normal"


func _scale_traps(root: Node, preset: Dictionary) -> void:
	if root == null:
		return
	for child in root.get_children():
		if not (child is Node2D):
			continue
		# Duck typing: tiap jenis rintangan punya properti yang berbeda.
		_scale_property(child, "movement_speed", float(preset["speed"]))
		_scale_property(child, "travel_distance", float(preset["travel"]))
		_scale_property(child, "fall_speed", float(preset["fall_speed"]))
		_scale_property(child, "speed", float(preset["speed"]))
		_set_property(child, "fall_delay", float(preset["fall_delay"]))


func _scale_property(node: Node, prop: String, factor: float) -> void:
	var value = node.get(prop)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return
	node.set(prop, float(value) * factor)


func _set_property(node: Node, prop: String, value: float) -> void:
	var current = node.get(prop)
	if typeof(current) != TYPE_FLOAT and typeof(current) != TYPE_INT:
		return
	node.set(prop, value)


func _keep_traps(root: Node, keep: bool) -> void:
	if root == null:
		return
	if keep:
		root.visible = true
		root.process_mode = Node.PROCESS_MODE_INHERIT
		return
	root.visible = false
	root.process_mode = Node.PROCESS_MODE_DISABLED
	for area in root.find_children("*", "Area2D", true, false):
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
	root.queue_free()


func _show_difficulty_label() -> void:
	var label := get_node_or_null("CanvasLayer/DifficultyLabel") as Label
	if label == null:
		return
	label.text = "Kesulitan: " + difficulty
	label.add_theme_color_override("font_color", _difficulty_color())


func _difficulty_color() -> Color:
	match difficulty:
		"Mudah":
			return Color(0.62, 0.95, 0.62)
		"Sulit":
			return Color(1.0, 0.55, 0.45)
		_:
			return Color(1.0, 0.86, 0.5)
