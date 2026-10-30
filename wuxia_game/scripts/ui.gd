extends RefCounted
## 共用的介面繪製與鍵盤輸入工具

const GOLD := Color(0.85, 0.71, 0.35)
const PAPER := Color(0.95, 0.9, 0.78)
const INK := Color(0.1, 0.09, 0.07)
const RED := Color(0.86, 0.3, 0.25)
const GREEN := Color(0.4, 0.82, 0.48)
const BLUE := Color(0.36, 0.64, 0.92)
const DIM := Color(0.6, 0.55, 0.45)

static var _font: Font = null


## 使用系統中文字型（Windows 微軟正黑體、macOS 蘋方、Linux Noto CJK）
static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Microsoft JhengHei", "PingFang TC", "Heiti TC", "Noto Sans CJK TC", "Noto Sans TC", "Microsoft YaHei", "Noto Sans CJK SC", "WenQuanYi Micro Hei", "WenQuanYi Zen Hei", "sans-serif"])
		_font = f
	return _font


## 文字繪製。置中／靠右且未指定寬度時，以 pos.x 為中心點／右緣
static func text(ci: CanvasItem, pos: Vector2, s: String, size := 18, col := PAPER, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0) -> void:
	if align != HORIZONTAL_ALIGNMENT_LEFT and width <= 0.0:
		var w := font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pos.x -= w * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else w
		align = HORIZONTAL_ALIGNMENT_LEFT
		width = -1.0
	if outline > 0:
		ci.draw_string_outline(font(), pos, s, align, width, size, outline, Color(0, 0, 0, 0.85))
	ci.draw_string(font(), pos, s, align, width, size, col)


static func panel(ci: CanvasItem, r: Rect2, alpha := 0.92) -> void:
	ci.draw_rect(r, Color(0.09, 0.075, 0.06, alpha))
	ci.draw_rect(r.grow(-4), Color(GOLD, 0.35), false, 1.0)
	ci.draw_rect(r, GOLD, false, 2.0)
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		ci.draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), GOLD)


static func bar(ci: CanvasItem, r: Rect2, ratio: float, col: Color) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), col)
	ci.draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)


## 把鍵盤事件轉成動作名稱：up/down/left/right/ok/cancel/reroll/music
static func key(event: InputEvent) -> String:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed:
		return ""
	var echo := ke.echo
	match ke.keycode:
		KEY_UP, KEY_W:
			return "up"
		KEY_DOWN, KEY_S:
			return "down"
		KEY_LEFT, KEY_A:
			return "left"
		KEY_RIGHT, KEY_D:
			return "right"
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z, KEY_J:
			return "" if echo else "ok"
		KEY_ESCAPE, KEY_X, KEY_K, KEY_BACKSPACE:
			return "" if echo else "cancel"
		KEY_R:
			return "" if echo else "reroll"
		KEY_M:
			return "" if echo else "music"
	return ""
