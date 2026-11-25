extends Node

## Pengaturan global permainan.
## Saat ini berisi volume suara:
##   - MUSIK LATAR : bus "Music" (lagu latar saat bermain)
##   - EFEK SUARA  : bus "SFX" (suara koin, tombol, dan lainnya)
##
## Nilai disimpan di user://settings.cfg, file yang sama dengan data skin,
## jadi tidak ada file konfigurasi terpisah.

signal audio_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const SAVE_DELAY: float = 0.3

var music_volume: float = 1.0
var sfx_volume: float = 1.0

var _save_timer: Timer


func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_load_settings()
	_apply_all()

	# Simpan setelah slider berhenti digeser, supaya tidak menulis file
	# puluhan kali saat slider ditarik.
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus(BUS_MUSIC, music_volume)
	audio_changed.emit()
	_schedule_save()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus(BUS_SFX, sfx_volume)
	audio_changed.emit()
	_schedule_save()


func _apply_all() -> void:
	_apply_bus(BUS_MUSIC, music_volume)
	_apply_bus(BUS_SFX, sfx_volume)


func _apply_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	# Volume 0% benar-benar senyap, bukan sekadar -80 dB.
	AudioServer.set_bus_mute(idx, value <= 0.0001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))


# Jaga-jaga kalau bus layout belum termuat: buat bus-nya saat runtime.
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _schedule_save() -> void:
	if _save_timer != null:
		_save_timer.start()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	# Muat dulu supaya bagian [player] (skin) tidak ikut terhapus.
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
