extends Node
## 程式合成的音效與背景音樂（自動載入：Audio）
## 不使用任何外部音檔：所有聲音在執行時以正弦波、雜訊與包絡線合成，
## 旋律採用中國五聲音階（宮商角徵羽），模擬古箏撥弦的音色。

const RATE := 22050
const SCALE := [0, 2, 4, 7, 9]
const BASE_FREQ := 293.66  # D4

var music_on := true
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx: Dictionary = {}
var _bgm: Dictionary = {}
var _want := ""
var _thread: Thread
var _b := PackedFloat32Array()  # 合成中的聲音緩衝區


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -9.0
	add_child(_bgm_player)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -5.0
		add_child(p)
		_sfx_players.append(p)
	_build_sfx()
	# 背景音樂較長，放到背景執行緒合成，避免開場卡頓
	_thread = Thread.new()
	_thread.start(_build_bgm)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


# ---------- 對外介面 ----------

func play_bgm(track: String) -> void:
	_want = track
	if not music_on or not _bgm.has(track):
		return  # 尚在合成中時，完成後會自動播放
	if _bgm_player.stream == _bgm[track] and _bgm_player.playing:
		return
	_bgm_player.stream = _bgm[track]
	_bgm_player.play()


func stop_bgm() -> void:
	_want = ""
	_bgm_player.stop()


func toggle_music() -> void:
	music_on = not music_on
	if music_on:
		play_bgm(_want)
	else:
		_bgm_player.stop()


func play_sfx(sfx_name: String) -> void:
	if not _sfx.has(sfx_name):
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = _sfx[sfx_name]
			p.play()
			return
	_sfx_players[0].stream = _sfx[sfx_name]
	_sfx_players[0].play()


func is_ready() -> bool:
	return not _bgm.is_empty()


# ---------- 合成工具 ----------

func _freq(degree: int) -> float:
	var octave := floori(degree / 5.0)
	var semis: int = SCALE[posmod(degree, 5)] + octave * 12
	return BASE_FREQ * pow(2.0, semis / 12.0)


func _buf(seconds: float) -> void:
	_b = PackedFloat32Array()
	_b.resize(int(seconds * RATE))
	_b.fill(0.0)


## 撥弦音：基音加上隨時間衰減的泛音，超出緩衝區時繞回開頭（讓循環音樂無縫）
func _pluck(start_s: float, freq: float, dur: float, amp: float, decay := 3.5, bright := 0.5) -> void:
	var start := int(start_s * RATE)
	var n := int(dur * RATE)
	var size := _b.size()
	var w := TAU * freq / RATE
	var env := 1.0
	var k := exp(-decay / RATE)
	for i in n:
		var ph := w * i
		var s := sin(ph) + bright * env * sin(2.0 * ph) + 0.3 * bright * env * env * sin(3.0 * ph)
		_b[(start + i) % size] += s * env * minf(1.0, i / 60.0) * amp
		env *= k


func _noise(start_s: float, dur: float, amp: float, decay: float, lowpass: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 991 + int(start_s * 1000.0)
	var start := int(start_s * RATE)
	var n := int(dur * RATE)
	var size := _b.size()
	var env := 1.0
	var k := exp(-decay / RATE)
	var lp := 0.0
	for i in n:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * lowpass
		_b[(start + i) % size] += lp * env * amp
		env *= k


## 低音鼓：頻率由高往低滑落的正弦波
func _kick(start_s: float, amp: float) -> void:
	var start := int(start_s * RATE)
	var n := int(0.25 * RATE)
	var size := _b.size()
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * (45.0 + 70.0 * exp(-t * 30.0)) / RATE
		_b[(start + i) % size] += sin(ph) * exp(-t * 14.0) * amp


## 簡單的回聲，讓樂聲有山谷迴盪的空間感
func _echo(delay_s: float, gain: float) -> void:
	var d := int(delay_s * RATE)
	var size := _b.size()
	var src := _b.duplicate()
	for i in size:
		_b[i] += src[(i - d + size) % size] * gain


func _to_stream(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := 0.85 / peak
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s


# ---------- 音效 ----------

func _build_sfx() -> void:
	_buf(0.12); _pluck(0.0, 1320.0, 0.1, 0.4, 35.0, 0.2); _sfx["select"] = _to_stream(_b, false)
	_buf(0.25); _pluck(0.0, 880.0, 0.12, 0.4, 25.0); _pluck(0.06, 1320.0, 0.18, 0.4, 18.0); _sfx["confirm"] = _to_stream(_b, false)
	_buf(0.25); _pluck(0.0, 660.0, 0.12, 0.4, 25.0); _pluck(0.07, 440.0, 0.16, 0.4, 18.0); _sfx["cancel"] = _to_stream(_b, false)
	_buf(0.2); _pluck(0.0, 170.0, 0.18, 0.5, 14.0, 1.0); _sfx["error"] = _to_stream(_b, false)
	_buf(0.06); _noise(0.0, 0.06, 0.4, 60.0, 0.12); _sfx["step"] = _to_stream(_b, false)
	_buf(0.22); _noise(0.0, 0.22, 0.6, 16.0, 0.55); _sfx["slash"] = _to_stream(_b, false)
	_buf(0.3); _kick(0.0, 0.8); _noise(0.0, 0.15, 0.5, 30.0, 0.35); _sfx["hit"] = _to_stream(_b, false)
	_buf(0.5); _kick(0.0, 0.8); _noise(0.0, 0.2, 0.5, 22.0, 0.45); _pluck(0.02, 1760.0, 0.45, 0.35, 8.0, 0.9); _sfx["crit"] = _to_stream(_b, false)
	_buf(0.7)
	for i in 4:
		_pluck(i * 0.08, _freq(5 + i * 2), 0.4, 0.35, 7.0)
	_sfx["heal"] = _to_stream(_b, false)
	_buf(1.1)
	for i in 6:
		_pluck(i * 0.07, _freq(5 + i), 0.6, 0.35, 5.0)
	_sfx["levelup"] = _to_stream(_b, false)
	_buf(1.6)
	var fan := [7, 9, 10, 12]
	for i in fan.size():
		_pluck(i * 0.14, _freq(fan[i]), 1.0 if i == 3 else 0.4, 0.4, 3.0 if i == 3 else 7.0)
	_pluck(0.42, _freq(0), 1.1, 0.35, 2.5)
	_sfx["victory"] = _to_stream(_b, false)
	_buf(1.8)
	var down := [5, 4, 2, 0]
	for i in down.size():
		_pluck(i * 0.3, _freq(down[i]), 0.8, 0.4, 3.0, 0.3)
	_sfx["defeat"] = _to_stream(_b, false)
	_buf(0.3); _pluck(0.0, 1568.0, 0.15, 0.35, 20.0); _pluck(0.07, 2093.0, 0.2, 0.35, 14.0); _sfx["coin"] = _to_stream(_b, false)


# ---------- 背景音樂 ----------

func _build_bgm() -> void:
	var tracks := {
		"title": _to_stream(_track_title(), true),
		"world": _to_stream(_track_world(), true),
		"battle": _to_stream(_track_battle(), true),
	}
	call_deferred("_on_bgm_built", tracks)


func _on_bgm_built(tracks: Dictionary) -> void:
	_thread.wait_to_finish()
	_bgm = tracks
	if _want != "":
		play_bgm(_want)


## 標題：慢板，悠遠的古箏旋律配上低音持續音
func _track_title() -> PackedFloat32Array:
	var beat := 60.0 / 72.0
	var melody := [7, 8, 9, 7, 8, 7, 5, 4, 5, 7, 4, 2, 4, 2, 0, -1]
	_buf(beat * melody.size())
	for i in melody.size():
		if melody[i] >= 0:
			_pluck(i * beat, _freq(melody[i]), 1.8, 0.32, 2.2, 0.45)
		if i % 2 == 1 and melody[i] >= 0:
			_pluck((i + 0.5) * beat, _freq(melody[i] + 2), 0.9, 0.12, 4.0, 0.3)
	for bar in 4:
		_pluck(bar * 4 * beat, _freq(-5 if bar % 2 == 0 else -2), 4.0 * beat, 0.3, 0.9, 0.2)
	_echo(beat * 0.75, 0.3)
	return _b


## 大地圖：中板，隨機漫步產生的旋律（固定種子，每次相同）
func _track_world() -> PackedFloat32Array:
	var beat := 60.0 / 92.0
	var beats := 32
	_buf(beat * beats)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261030
	var deg := 5
	for i in beats * 2:
		if rng.randf() < 0.22 and i % 4 != 0:
			continue
		deg = clampi(deg + rng.randi_range(-2, 2), 2, 11)
		if i % 16 == 15:
			deg = 5
		_pluck(i * beat * 0.5, _freq(deg), 1.0, 0.26, 3.2, 0.5)
	var roots := [0, 0, 3, 4, 0, 2, 3, 0]
	for bar in 8:
		for k in 2:
			_pluck((bar * 4 + k * 2) * beat, _freq(roots[bar] - 5), 1.6, 0.3, 1.8, 0.3)
	for i in beats:
		_pluck(i * beat, 1200.0, 0.05, 0.05, 60.0, 0.0)
	_echo(beat * 0.5, 0.22)
	return _b


## 戰鬥：快板，鼓點與急促的旋律
func _track_battle() -> PackedFloat32Array:
	var beat := 60.0 / 138.0
	var beats := 32
	_buf(beat * beats)
	for i in beats:
		_kick(i * beat, 0.55)
		if i % 2 == 1:
			_noise(i * beat, 0.15, 0.3, 20.0, 0.6)
		_noise((i + 0.5) * beat, 0.04, 0.12, 80.0, 0.9)
	var roots := [0, 0, -2, -1, 0, 0, 1, -1]
	for i in beats * 2:
		var r: int = roots[int(i / 8.0)]
		_pluck(i * beat * 0.5, _freq(r - 5 + (2 if i % 2 == 1 else 0)), 0.3, 0.26, 7.0, 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 138
	var deg := 7
	for i in beats * 2:
		if i % 8 == 7:
			continue
		deg = clampi(deg + rng.randi_range(-2, 2), 4, 12)
		_pluck(i * beat * 0.5, _freq(deg), 0.35, 0.22, 6.0, 0.8)
	return _b
