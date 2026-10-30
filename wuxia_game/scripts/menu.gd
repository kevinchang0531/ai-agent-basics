extends RefCounted
## 通用選單框：標題、說明文字、可選項目。選擇後呼叫 on_choose(index)，取消時傳入 -1。

const UI = preload("res://scripts/ui.gd")

var title := ""
var lines: Array = []
var options: Array = []
var disabled: Array = []
var index := 0
var on_choose: Callable
var cancelable := true
var width := 380.0
var font_size := 18


func handle(k: String) -> void:
	match k:
		"up":
			index = wrapi(index - 1, 0, options.size())
			Audio.play_sfx("select")
		"down":
			index = wrapi(index + 1, 0, options.size())
			Audio.play_sfx("select")
		"ok":
			if index < disabled.size() and disabled[index]:
				Audio.play_sfx("error")
				return
			Audio.play_sfx("confirm")
			on_choose.call(index)
		"cancel":
			if cancelable:
				Audio.play_sfx("cancel")
				on_choose.call(-1)


func get_height() -> float:
	var h := 24.0 + lines.size() * (font_size + 6) + options.size() * (font_size + 12)
	if title != "":
		h += 36.0
	return h


func draw_at(ci: CanvasItem, pos: Vector2) -> void:
	var r := Rect2(pos, Vector2(width, get_height()))
	UI.panel(ci, r)
	var y := pos.y + 12.0
	if title != "":
		UI.text(ci, Vector2(pos.x + 18, y + 22), title, font_size + 4, UI.GOLD)
		ci.draw_line(Vector2(pos.x + 16, y + 32), Vector2(r.end.x - 16, y + 32), Color(UI.GOLD, 0.4), 1.0)
		y += 36.0
	for l in lines:
		UI.text(ci, Vector2(pos.x + 18, y + font_size), str(l), font_size - 2, UI.PAPER, HORIZONTAL_ALIGNMENT_LEFT, width - 30)
		y += font_size + 6
	var lh := font_size + 12
	for i in options.size():
		var sel := i == index
		var dis: bool = i < disabled.size() and disabled[i]
		if sel:
			ci.draw_rect(Rect2(pos.x + 10, y + 2, width - 20, lh - 2), Color(UI.GOLD, 0.2))
			var cy := y + lh * 0.5 + 1
			ci.draw_colored_polygon(PackedVector2Array([Vector2(pos.x + 16, cy - 5), Vector2(pos.x + 24, cy), Vector2(pos.x + 16, cy + 5)]), UI.GOLD)
		var col: Color = UI.DIM if dis else (UI.GOLD if sel else UI.PAPER)
		UI.text(ci, Vector2(pos.x + 30, y + font_size + 3), str(options[i]), font_size, col, HORIZONTAL_ALIGNMENT_LEFT, width - 40)
		y += lh


func draw_centered(ci: CanvasItem, screen := Vector2(960, 640)) -> void:
	draw_at(ci, Vector2((screen.x - width) * 0.5, (screen.y - get_height()) * 0.5))
