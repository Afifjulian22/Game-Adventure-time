extends Area2D

@onready var game_manager: Node = %GameManager

var _collected: bool = false


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	# Hanya perangkat pemilik karakter itu yang boleh mengambil koin,
	# supaya satu koin tidak dihitung dua kali.
	if body.has_method("is_local_player") and not body.is_local_player():
		return
	_collected = true
	game_manager.request_coin(self)
