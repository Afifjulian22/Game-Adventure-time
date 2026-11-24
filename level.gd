extends Node2D

## Mengatur siapa yang mengendalikan tiap karakter di level.
## - Single player : hanya Player 1 yang ada.
## - Multiplayer   : host mengendalikan Player 1, client mengendalikan Player 2.
## Skin tiap pemain diambil dari Net (dipilih di menu CUSTOMIZE).

@onready var player1: CharacterBody2D = $player
@onready var player2: CharacterBody2D = $Player2


func _ready() -> void:
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

