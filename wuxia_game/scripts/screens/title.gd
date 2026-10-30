extends Node2D
## 標題畫面：月夜山水、飄落的花瓣，以及開始／讀檔／進度紀錄選單

const UI = preload("res://scripts/ui.gd")
const Art = preload("res://scripts/art.gd")
const MenuBox = preload("res://scripts/menu.gd")

var main
var args := {}
var t := 0.0
var age := 0.0
var menu: MenuBox
var sub: MenuBox = null
var stars: Array = []
var petals: Array = []
var ridges: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		stars.append(Vector3(rng.randf() * 960.0, rng.randf() * 320.0, rng.randf() * TAU))
	for i in 28:
		petals.append({"p": Vector2(rng.randf() * 960.0, rng.randf() * 640.0), "v": rng.randf_range(20.0, 45.0), "ph": rng.randf() * TAU})
	# 三層遠近山脈，越遠越淡
	var layers := [[300.0, 70.0, Color(0.2, 0.24, 0.36)], [370.0, 55.0, Color(0.13, 0.16, 0.26)], [440.0, 45.0, Color(0.07, 0.09, 0.15)]]
	for li in layers.size():
		var pts := PackedVector2Array([Vector2(0, 640)])
		for i in 41:
			var x := i * 24.0
			var y: float = layers[li][0] - absf(sin(x * 0.006 + li * 1.7)) * layers[li][1] - sin(x * 0.021 + li) * 14.0
			pts.append(Vector2(x, y))
		pts.append(Vector2(960, 640))
		ridges.append([pts, layers[li][2]])
	menu = MenuBox.new()
	menu.options = ["新的江湖", "讀取進度", "進度紀錄", "離開遊戲"]
	menu.cancelable = false
	menu.width = 240.0
	menu.on_choose = _on_main
	Audio.play_bgm("title")


func _process(delta: float) -> void:
	t += delta
	age += delta
	for p in petals:
		p.p += Vector2(sin(t + p.ph) * 18.0 - 12.0, p.v) * delta
		if p.p.y > 650.0:
			p.p = Vector2(randf() * 1000.0, -10.0)
		if p.p.x < -10.0:
			p.p = Vector2(970.0, p.p.y)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if age < 0.25:
		return
	var k := UI.key(event)
	if k == "":
		return
	if k == "music":
		Audio.toggle_music()
		return
	if sub:
		sub.handle(k)
	else:
		menu.handle(k)


func _on_main(i: int) -> void:
	match i:
		0:
			main.change_screen("create")
		1:
			_open_load()
		2:
			_open_history()
		3:
			get_tree().quit()


func _open_load() -> void:
	sub = MenuBox.new()
	sub.title = "讀取進度"
	sub.width = 520.0
	for s in SaveDB.SLOT_COUNT:
		sub.options.append(SaveDB.slot_label(s))
		sub.disabled.append(not SaveDB.has_slot(s))
	sub.options.append("返回")
	sub.disabled.append(false)
	sub.on_choose = _on_load


func _on_load(i: int) -> void:
	if i < 0 or i >= SaveDB.SLOT_COUNT:
		sub = null
		return
	var data := SaveDB.load_slot(i)
	if data.is_empty():
		return
	Game.from_dict(data)
	main.change_screen("world", {"message": "已讀取「%s」。" % SaveDB.SLOT_NAMES[i]})


func _open_history() -> void:
	sub = MenuBox.new()
	sub.title = "江湖足跡（共 %d 筆進度紀錄）" % SaveDB.history_count()
	sub.width = 640.0
	sub.font_size = 17
	for h in SaveDB.get_history(10):
		sub.lines.append("%s　%s Lv%d　%s　銀兩 %d　%s" % [str(h.get("time", "")).substr(5, 11), h.get("name", "?"), int(h.get("lv", 1)), h.get("location", ""), int(h.get("gold", 0)), h.get("event", "")])
	if sub.lines.is_empty():
		sub.lines.append("尚無任何紀錄，踏入江湖後每次存檔都會留下足跡。")
	sub.options = ["返回"]
	sub.on_choose = func(_i): sub = null


func _draw() -> void:
	# 夜空漸層
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(960, 0), Vector2(960, 640), Vector2(0, 640)]),
		PackedColorArray([Color(0.04, 0.05, 0.12), Color(0.06, 0.05, 0.14), Color(0.32, 0.2, 0.3), Color(0.28, 0.18, 0.28)]))
	for s in stars:
		draw_circle(Vector2(s.x, s.y), 1.2, Color(1, 1, 0.9, 0.35 + 0.35 * sin(t * 2.0 + s.z)))
	# 明月與光暈
	var moon := Vector2(700, 150)
	for i in 5:
		draw_circle(moon, 70.0 + i * 18.0, Color(1, 0.95, 0.8, 0.035))
	draw_circle(moon, 62.0, Color(0.98, 0.94, 0.82))
	draw_circle(moon + Vector2(-18, -12), 10.0, Color(0.9, 0.86, 0.74))
	draw_circle(moon + Vector2(16, 18), 7.0, Color(0.9, 0.86, 0.74))
	for r in ridges:
		draw_colored_polygon(r[0], r[1])
	# 山崖、松樹與俠客剪影
	draw_colored_polygon(PackedVector2Array([Vector2(600, 640), Vector2(640, 470), Vector2(700, 452), Vector2(790, 462), Vector2(830, 520), Vector2(860, 640)]), Color(0.03, 0.04, 0.07))
	Art.pine(self, Vector2(805, 470), 1.6, Color(0.03, 0.06, 0.07))
	Art.draw_unit(self, "hero", Vector2(715, 455), 1.3, t, -1)
	# 雲霧
	for i in 3:
		var y := 430.0 + i * 50.0
		var x := fmod(t * (12.0 + i * 6.0) + i * 300.0, 1300.0) - 300.0
		draw_rect(Rect2(x, y, 420, 14), Color(0.8, 0.8, 0.9, 0.06))
		draw_rect(Rect2(x + 60, y + 10, 300, 10), Color(0.8, 0.8, 0.9, 0.05))
	for p in petals:
		var q: Vector2 = p.p
		Art.ellipse(self, q, Vector2(3.5, 2.0), Color(1, 0.7, 0.8, 0.8))
	# 標題
	UI.text(self, Vector2(80, 170), "江湖俠客行", 84, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	UI.text(self, Vector2(88, 214), "原創武俠角色扮演 · 大地圖探索 · 戰棋回合戰鬥", 20, UI.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	draw_rect(Rect2(84, 228, 360, 2), Color(UI.GOLD, 0.6))
	menu.draw_at(self, Vector2(90, 280))
	UI.text(self, Vector2(90, 610), "↑↓ 選擇　Enter 確認　Esc 返回　M 音樂開關", 15, UI.DIM)
	if not Audio.is_ready():
		UI.text(self, Vector2(940, 620), "正在調弦（合成音樂）…", 14, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT, -1)
	if sub:
		draw_rect(Rect2(0, 0, 960, 640), Color(0, 0, 0, 0.45))
		sub.draw_centered(self)
