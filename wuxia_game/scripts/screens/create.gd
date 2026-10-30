extends Node2D
## 創角畫面：輸入姓名、擲骰決定四項天賦

const UI = preload("res://scripts/ui.gd")
const Art = preload("res://scripts/art.gd")

const STAT_INFO := [
	["str", "臂力", "影響攻擊力"],
	["con", "根骨", "影響氣血與防禦"],
	["agi", "身法", "影響移動距離與出手順序"],
	["wis", "悟性", "影響內力與武功修練速度"],
]

var main
var args := {}
var stats := {}
var stage := "name"
var name_edit: LineEdit
var rng := RandomNumberGenerator.new()
var t := 0.0
var age := 0.0
var roll_count := 0


func _ready() -> void:
	rng.randomize()
	stats = Game.roll_stats(rng)
	name_edit = LineEdit.new()
	name_edit.position = Vector2(470, 118)
	name_edit.size = Vector2(260, 42)
	name_edit.max_length = 8
	name_edit.text = "無名少俠"
	name_edit.add_theme_font_override("font", UI.font())
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.text_submitted.connect(_on_name_submitted)
	add_child(name_edit)
	name_edit.grab_focus()
	name_edit.select_all()
	Audio.play_bgm("title")


func _process(delta: float) -> void:
	t += delta
	age += delta
	queue_redraw()


func _on_name_submitted(_text: String) -> void:
	name_edit.release_focus()
	stage = "stats"
	Audio.play_sfx("confirm")


func _unhandled_input(event: InputEvent) -> void:
	if age < 0.25 or stage != "stats":
		return
	match UI.key(event):
		"reroll":
			stats = Game.roll_stats(rng)
			roll_count += 1
			Audio.play_sfx("coin")
		"ok":
			var n := name_edit.text.strip_edges()
			Game.new_game(n if n != "" else "無名少俠", stats)
			Audio.play_sfx("levelup")
			main.change_screen("world", {"intro": true})
		"cancel":
			stage = "name"
			name_edit.grab_focus()
		"music":
			Audio.toggle_music()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color(0.12, 0.1, 0.09))
	# 卷軸
	var scroll := Rect2(150, 40, 660, 560)
	draw_rect(scroll, Color(0.93, 0.86, 0.7))
	for i in 12:
		draw_line(Vector2(scroll.position.x, 60 + i * 46), Vector2(scroll.end.x, 64 + i * 46), Color(0.8, 0.7, 0.52, 0.35), 1.0)
	draw_rect(Rect2(130, 30, 700, 18), Color(0.45, 0.22, 0.12))
	draw_rect(Rect2(130, 592, 700, 18), Color(0.45, 0.22, 0.12))
	UI.text(self, Vector2(480, 96), "初入江湖", 36, UI.INK, HORIZONTAL_ALIGNMENT_CENTER, 0)
	# 角色預覽
	draw_circle(Vector2(300, 330), 95, Color(0.85, 0.76, 0.58))
	Art.draw_unit(self, "hero", Vector2(300, 400), 2.6, t)
	UI.text(self, Vector2(300, 470), name_edit.text if name_edit else "", 24, UI.INK, HORIZONTAL_ALIGNMENT_CENTER, 0)
	UI.text(self, Vector2(400, 147), "姓名", 22, UI.INK)
	# 天賦
	var y := 200.0
	for info in STAT_INFO:
		var v: int = stats[info[0]]
		UI.text(self, Vector2(410, y + 18), info[1], 22, UI.INK)
		UI.bar(self, Rect2(470, y + 2, 200, 18), float(v) / Game.STAT_MAX, Color(0.7, 0.25, 0.18))
		UI.text(self, Vector2(682, y + 18), str(v), 22, UI.INK)
		UI.text(self, Vector2(470, y + 42), info[2], 15, Color(0.4, 0.33, 0.25))
		y += 62.0
	var hp := 50 + int(stats.con) * 3
	var mp := 20 + int(stats.wis) * 2
	var mv := 3 + int(stats.agi / 20.0)
	UI.text(self, Vector2(410, 470), "氣血 %d　內力 %d　移動 %d 格" % [hp, mp, mv], 20, Color(0.25, 0.2, 0.15))
	var total := int(stats.str) + int(stats.con) + int(stats.agi) + int(stats.wis)
	UI.text(self, Vector2(410, 500), "天賦總和 %d（已擲骰 %d 次）" % [total, roll_count], 16, Color(0.45, 0.35, 0.25))
	var hint := "輸入姓名後按 Enter" if stage == "name" else "R 重新擲骰　Enter 踏入江湖　Esc 修改姓名"
	UI.text(self, Vector2(480, 566), hint, 18, Color(0.55, 0.15, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 0)
