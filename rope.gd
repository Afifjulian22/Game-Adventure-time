extends Node2D

## Tali yang mengikat Player 1 dan Player 2.
## Memakai tekstur dari Free/Main Characters/Tali.jpg (sudah dipotong jadi
## rope_tile.png), diulang memakai Line2D sehingga tidak perlu gambar panjang.
## Panjang maksimal tali juga dipakai player.gd sebagai batas gerak.

@export var max_length: float = 280.0
@export_range(8, 64) var segments: int = 24
@export var rope_width: float = 10.0
@export var anchor_offset: Vector2 = Vector2(0, -12)
@export var max_sag: float = 36.0
@export var rope_texture: Texture2D = preload("res://rope_tile.png")

var _line: Line2D


func _ready() -> void:
	z_index = 1

	_line = Line2D.new()
	_line.texture = rope_texture
	_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	_line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_line.width = rope_width
	_line.default_color = Color.WHITE
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_BOX
	_line.end_cap_mode = Line2D.LINE_CAP_BOX
	_line.antialiased = false
	_line.visible = false
	add_child(_line)


func _process(_delta: float) -> void:
	var players := _players()
	if players.size() < 2:
		_line.visible = false
		return

	var a: Vector2 = to_local(players[0].global_position + anchor_offset)
	var b: Vector2 = to_local(players[1].global_position + anchor_offset)
	var distance := a.distance_to(b)

	# Tali melengkung kalau kendor; tetap melengkung sedikit saat tegang
	# supaya tidak terlihat seperti balok kayu.
	var sag := minf((max_length - minf(distance, max_length)) * 0.25 + 4.0, max_sag)

	var points := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / float(segments)
		var p := a.lerp(b, t)
		p.y += sag * 4.0 * t * (1.0 - t)
		points.append(p)

	_line.points = points
	_line.visible = true


func _players() -> Array:
	var result: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			result.append(p)
	return result


# Kedua karakter hanya boleh berjauhan sejauh ini (dipakai player.gd).
func get_max_length() -> float:
	return max_length
