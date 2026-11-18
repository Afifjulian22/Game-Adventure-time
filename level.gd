extends Node2D

## Mengatur siapa yang mengendalikan tiap karakter di level.
## - Single player : hanya Player 1 (Afif) yang ada.
## - Multiplayer   : host mengendalikan Player 1 (Afif),
##                   client mengendalikan Player 2 (Pink Man).

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
		return

	# Peer id client berbeda-beda (bukan selalu 2), jadi diambil dari Net:
	# - host tahu id client dari daftar peers
	# - client tahu id dirinya sendiri
	var client_peer: int = net.peers[0] if not net.peers.is_empty() else 2
	var my_peer: int = net.my_id()

	if host:
		player1.setup_player(1, true, 1)             # Afif milik host
		player2.setup_player(2, false, client_peer)  # Pink Man milik client
	else:
		player1.setup_player(1, false, 1)            # Afif milik host
		player2.setup_player(2, true, my_peer)       # Pink Man milik client ini
