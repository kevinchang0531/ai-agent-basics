extends Node2D
## 結局畫面：朝霞中的赤霞峰與片尾字幕，並寫入一筆「通關」進度紀錄

const UI = preload("res://scripts/ui.gd")
const Art = preload("res://scripts/art.gd")

const STORY := [
	"赤煉魔君伏誅，赤霞峰上的紅霧終於散去。",
	"消息傳回清風鎮，鎮民張燈結綵，說書人連夜編成新段子。",
	"",
	"少俠婉拒了各派掌門的邀請，",
	"只在客棧留下一句話：",
	"「江湖路遠，有緣再會。」",
	"",
	"── 江湖俠客行　完 ──",
	"",
	"美術：Godot draw API 程式繪製",
	"音樂與音效：五聲音階即時合成",
	"感謝遊玩！",
]

var main
var args := {}
var t := 0.0


func _ready() -> void:
	SaveDB.save_slot(0, Game.to_dict(), Game.summary(), "擊敗赤煉魔君・通關")
	Audio.play_bgm("title")


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if t > 2.0 and UI.key(event) == "ok":
		main.change_screen("title")


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(960, 0), Vector2(960, 640), Vector2(0, 640)]),
		PackedColorArray([Color(0.3, 0.35, 0.6), Color(0.35, 0.38, 0.62), Color(1.0, 0.7, 0.45), Color(0.98, 0.65, 0.42)]))
	draw_circle(Vector2(480, 470), 90.0, Color(1, 0.85, 0.55, 0.9))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 640), Vector2(0, 470), Vector2(200, 400), Vector2(380, 470), Vector2(560, 380), Vector2(760, 460), Vector2(960, 410), Vector2(960, 640)]), Color(0.25, 0.18, 0.25))
	Art.draw_unit(self, "hero", Vector2(440, 560), 1.6, t)
	if Game.party.size() > 1:
		Art.draw_unit(self, "heroine", Vector2(520, 560), 1.5, t + 1.0, -1)
	var y := 640.0 - t * 40.0
	for line in STORY:
		var yy := y
		if yy > -30.0 and yy < 660.0:
			UI.text(self, Vector2(480, yy), line, 24, UI.PAPER, HORIZONTAL_ALIGNMENT_CENTER, -1, 5)
		y += 42.0
	if t > 2.0:
		UI.text(self, Vector2(940, 628), "按 Enter 回到標題", 15, UI.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, -1, 3)
