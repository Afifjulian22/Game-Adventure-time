extends CharacterBody2D

# ------------------------------------------------------------------ tuning
@export var speed: float = 240.0
@export var jump_velocity: float = -400.0
@export var max_jumps: int = 2
@export var respawn_delay: float = 0.55
@export var invulnerable_time: float = 1.0
@export var fall_limit: float = 1000.0

# --- lives / hearts -------------------------------------------------------
const MAX_LIVES: int = 3
const HEART_SHEET := preload("res://Free/Pixel Heart Sprite Sheet 32x32.png")
const HEART_SIZE: float = 44.0
const HEART_GAP: float = 6.0

# --- multiplayer ----------------------------------------------------------
const NET_SYNC_INTERVAL: float = 0.05   # 20 kali per detik
const NET_SMOOTHING: float = 20.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var btn_left: TouchScreenButton = $CanvasLayer/BtnLeft
@onready var btn_right: TouchScreenButton = $CanvasLayer/BtnRight
@onready var btn_jump: TouchScreenButton = $CanvasLayer/BtnJump
@onready var camera: Camera2D = $Camera2D

var jump_count: int = 0
var spawn_point: Vector2 = Vector2.ZERO
var safe_position: Vector2 = Vector2.ZERO
var is_dead: bool = false
var is_invulnerable: bool = false
var lives: int = MAX_LIVES
var _heart_full: AtlasTexture
var _heart_empty: AtlasTexture

# Player 1 = Afif (peer 1 / host), Player 2 = Pink Man (peer 2 / client).
var player_index: int = 1
var local_control: bool = true
var _sync_timer: float = 0.0
var _remote_target: Vector2 = Vector2.ZERO
var _has_remote_target: bool = false

# --- tali ---------------------------------------------------------------
var _rope: Node = null
var _rope_length: float = 0.0


func _ready() -> void:
	_rope = get_parent().get_node_or_null("Rope") if get_parent() != null else null

	spawn_point = global_position
	safe_position = global_position

	# Heart sprite sheet (32x32): frame 0 = full, frame 2 = empty.
	_heart_full = AtlasTexture.new()
	_heart_full.atlas = HEART_SHEET
	_heart_full.region = Rect2(0, 0, 32, 32)

	_heart_empty = AtlasTexture.new()
	_heart_empty.atlas = HEART_SHEET
	_heart_empty.region = Rect2(64, 0, 32, 32)

	lives = MAX_LIVES
	_update_hearts()

	_layout_touch_buttons()
	get_viewport().size_changed.connect(_layout_touch_buttons)


# ------------------------------------------------------------------ multiplayer
# Dipanggil oleh level.gd sebelum frame pertama.
# index       : 1 = Afif, 2 = Pink Man (identitas karakter saja)
# local       : true kalau karakter ini dikendalikan perangkat ini
# owner_peer  : peer id pemilik karakter (host = 1, client = id acak dari ENet)
func setup_player(index: int, local: bool, owner_peer: int) -> void:
	player_index = index
	local_control = local
	set_multiplayer_authority(owner_peer)

	camera.enabled = local_control
	$CanvasLayer.visible = local_control
	set_physics_process(local_control)
	set_process(not local_control)

	if not local_control:
		velocity = Vector2.ZERO
		_remote_target = global_position

	# Tali hanya mengikat saat bermain berdua.
	if local_control and _rope != null and _net_is_multiplayer():
		_rope_length = _rope.get_max_length()


func is_local_player() -> bool:
	return local_control


# ------------------------------------------------------------------ skin
# Skin standar (32x32) memakai skala/offset yang sama dengan Pink Man,
# sedangkan Afif memakai sprite custom yang lebih besar.
const SKIN_DIR := "res://Free/Main Characters/"
const STD_SCALE := Vector2(1.1, 1.1)
const STD_OFFSET := Vector2(0, -15.6)
const AFIF_SCALE := Vector2(0.4, 0.4)
const AFIF_OFFSET := Vector2(0, -46.5)

static var _frame_cache: Dictionary = {}


## Ganti tampilan karakter. Aman dipanggil kapan saja (saat mulai game
## maupun saat skin lawan baru diterima dari jaringan).
func apply_skin(skin_name: String) -> void:
	if sprite == null:
		return
	var frames := _frames_for(skin_name)
	if frames == null or not frames.has_animation("idle"):
		if skin_name == "Afif":
			return
		skin_name = "Afif"
		frames = _frames_for("Afif")
	if frames == null or not frames.has_animation("idle"):
		return
	sprite.sprite_frames = frames
	if skin_name == "Afif":
		sprite.scale = AFIF_SCALE
		sprite.offset = AFIF_OFFSET
	else:
		sprite.scale = STD_SCALE
		sprite.offset = STD_OFFSET
	sprite.play("idle")


func _frames_for(skin_name: String) -> SpriteFrames:
	if _frame_cache.has(skin_name):
		return _frame_cache[skin_name]
	var frames: SpriteFrames = null
	if skin_name == "Afif":
		frames = _load_afif_frames()
	else:
		frames = _build_standard_frames(skin_name)
	if frames != null:
		_frame_cache[skin_name] = frames
	return frames


## Afif memakai 3 spritesheet custom. Supaya hasilnya sama persis dengan
## player.tscn, SpriteFrames-nya diambil dari scene itu (di-load saat runtime
## agar tidak terjadi referensi melingkar).
func _load_afif_frames() -> SpriteFrames:
	var packed := load("res://player.tscn") as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	var anim := inst.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var frames: SpriteFrames = anim.sprite_frames if anim != null else null
	inst.free()
	return frames


## Empat karakter Pixel Adventure: satu baris frame 32x32 per animasi.
func _build_standard_frames(skin_name: String) -> SpriteFrames:
	var dir := SKIN_DIR + skin_name + "/"
	var sheets := {
		"idle": ["Idle (32x32).png", 6.0, true],
		"run": ["Run (32x32).png", 10.0, true],
		"jump": ["Jump (32x32).png", 1.0, true],
		"2jump": ["Double Jump (32x32).png", 8.0, true],
		"fall": ["Fall (32x32).png", 1.0, true],
		"hit": ["Hit (32x32).png", 10.0, false],
	}
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var loaded := 0
	for anim in sheets:
		var info: Array = sheets[anim]
		var tex := load(dir + String(info[0])) as Texture2D
		if tex == null:
			continue
		loaded += 1
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(info[1]))
		frames.set_animation_loop(anim, bool(info[2]))
		var count: int = maxi(1, int(tex.get_width() / 32))
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 32, 0, 32, 32)
			frames.add_frame(anim, at)
	if loaded == 0:
		return null
	return frames


func _net_is_multiplayer() -> bool:
	var net := get_node_or_null("/root/Net")
	return net != null and net.is_multiplayer()


# Hanya karakter milik perangkat ini yang mengirim posisi ke perangkat lain.
func _send_state(delta: float) -> void:
	if not local_control or not _net_is_multiplayer():
		return

	_sync_timer += delta
	if _sync_timer < NET_SYNC_INTERVAL:
		return
	_sync_timer = 0.0

	_net_state.rpc(global_position, velocity, String(sprite.animation), sprite.flip_h, is_dead)


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(pos: Vector2, vel: Vector2, anim: String, flip: bool, dead: bool) -> void:
	_remote_target = pos
	_has_remote_target = true
	velocity = vel

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)

	sprite.flip_h = flip
	sprite.modulate.a = 0.5 if dead else 1.0


# Karakter lawan digerakkan halus menuju posisi terakhir dari jaringan.
func _process(delta: float) -> void:
	if local_control or not _has_remote_target:
		return

	global_position = global_position.lerp(_remote_target, clampf(delta * NET_SMOOTHING, 0.0, 1.0))


# Keep the on-screen pad and the hearts in the corners whatever the
# window / phone size is.
func _layout_touch_buttons() -> void:
	var vp := get_viewport_rect().size
	var margin := 110.0
	btn_left.position = Vector2(84.0, vp.y - margin)
	btn_right.position = Vector2(196.0, vp.y - margin)
	btn_jump.position = Vector2(vp.x - margin, vp.y - margin)

	var hearts := _hearts()
	var start_x := 24.0
	for i in hearts.size():
		hearts[i].size = Vector2(HEART_SIZE, HEART_SIZE)
		hearts[i].position = Vector2(start_x + i * (HEART_SIZE + HEART_GAP), 20.0)


func _hearts() -> Array:
	return [$CanvasLayer/Heart1, $CanvasLayer/Heart2, $CanvasLayer/Heart3]


func _update_hearts() -> void:
	var hearts := _hearts()
	for i in hearts.size():
		hearts[i].texture = _heart_full if i < lives else _heart_empty


func _physics_process(delta: float) -> void:
	if is_dead:
		_send_state(delta)
		return

	# --- gravity -------------------------------------------------------
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		jump_count = 0

	# --- jump (double jump included) -----------------------------------
	if Input.is_action_just_pressed("jump"):
		if is_on_floor() or jump_count < max_jumps:
			velocity.y = jump_velocity
			jump_count += 1

	# --- walk ----------------------------------------------------------
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 6.0 * delta)

	move_and_slide()

	_apply_rope_constraint()

	# --- respawn anchor: remember the last static platform we stood on --
	if is_on_floor() and not _standing_on_moving_body():
		safe_position = global_position

	if global_position.y > fall_limit:
		play_fall()
		die()
		return

	_update_animation(direction)
	_send_state(delta)


# --- tali ---------------------------------------------------------------
func _rope_partner_node() -> Node2D:
	var best: Node2D = null
	var best_distance := INF

	for p in get_tree().get_nodes_in_group("player"):
		if p == self or not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		if p.get("is_dead") == true:
			continue
		var d: float = global_position.distance_squared_to(p.global_position)
		if d < best_distance:
			best_distance = d
			best = p

	return best


# Menjaga jarak supaya tidak melebihi panjang tali.
# Setiap perangkat hanya mengoreksi setengah kelebihan, jadi totalnya pas.
func _apply_rope_constraint() -> void:
	if _rope_length <= 0.0 or is_dead:
		return

	var partner := _rope_partner_node()
	if partner == null:
		return

	var offset := global_position - partner.global_position
	var distance := offset.length()
	if distance <= 0.001 or distance <= _rope_length:
		return

	var direction := offset / distance
	global_position -= direction * (distance - _rope_length) * 0.5

	# Buang kecepatan yang menjauh supaya tidak terus menekan tali.
	var away := velocity.dot(direction)
	if away > 0.0:
		velocity -= direction * away


func _standing_on_moving_body() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is AnimatableBody2D:
			return true
	return false


func _update_animation(direction: float) -> void:
	if not is_on_floor():
		# Di udara: selalu animasi lompat, baik saat naik maupun saat
		# turun. Animasi "fall" TIDAK dipakai di sini -- lihat play_fall().
		if jump_count >= max_jumps:
			sprite.play("2jump")
		else:
			sprite.play("jump")
	else:
		if absf(direction) > 0.01:
			sprite.play("run")
		else:
			sprite.play("idle")

	if direction < 0.0:
		sprite.flip_h = true
	elif direction > 0.0:
		sprite.flip_h = false


# Reaksi saat terkena jebakan (duri, api, gergaji).
# HANYA fungsi ini yang boleh memutar animasi "hit".
func play_hit() -> void:
	if not local_control or is_dead or is_invulnerable:
		return
	sprite.play("hit")


# Jatuh ke pembatas dunia (jurang / batas bawah map).
# HANYA fungsi ini yang boleh memutar animasi "fall".
func play_fall() -> void:
	if not local_control or is_dead or is_invulnerable:
		return
	sprite.play("fall")


# Dipanggil saat jatuh ke jurang / melewati batas bawah map.
# Tidak mengubah animasi sama sekali.
func die() -> void:
	if not local_control or is_dead or is_invulnerable:
		return

	is_dead = true
	lives -= 1
	_update_hearts()
	velocity = Vector2.ZERO

	# Nyawa habis: bukan respawn sendiri, tapi seluruh level diulang
	# dari awal untuk KEDUA pemain (poin ikut kembali ke 0).
	if lives <= 0:
		_restart_level_after_delay()
		return

	await get_tree().create_timer(respawn_delay, false).timeout
	_respawn()


func _restart_level_after_delay() -> void:
	await get_tree().create_timer(respawn_delay, false).timeout
	var net := get_node_or_null("/root/Net")
	if net != null:
		net.restart_level()


func _respawn() -> void:
	# Masih punya nyawa: respawn di pijakan terakhir.
	global_position = safe_position

	velocity = Vector2.ZERO
	jump_count = 0
	is_dead = false
	sprite.play("idle")

	# Short grace period so the player is not instantly killed again.
	is_invulnerable = true
	sprite.modulate.a = 0.5
	await get_tree().create_timer(invulnerable_time, false).timeout
	if not is_inside_tree():
		return
	sprite.modulate.a = 1.0
	is_invulnerable = false
