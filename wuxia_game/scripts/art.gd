extends RefCounted
## 程式繪圖美術：角色、地形、建築全部以 CanvasItem 的 draw_* API 即時繪製，
## 不需要任何外部圖片素材。角色座標以「腳底中心」為原點、向右為面向。

const SKIN := Color(0.96, 0.82, 0.66)

const PAL := {
	"hero": {"robe": Color(0.22, 0.42, 0.72), "trim": Color(0.94, 0.9, 0.78), "hair": Color(0.08, 0.07, 0.07), "pants": Color(0.16, 0.16, 0.22), "weapon": "sword", "style": "topknot"},
	"heroine": {"robe": Color(0.86, 0.38, 0.5), "trim": Color(0.98, 0.92, 0.85), "hair": Color(0.1, 0.07, 0.07), "pants": Color(0.42, 0.2, 0.3), "weapon": "sword", "style": "long"},
	"bandit": {"robe": Color(0.52, 0.36, 0.22), "trim": Color(0.3, 0.2, 0.12), "hair": Color(0.12, 0.1, 0.08), "pants": Color(0.25, 0.2, 0.15), "weapon": "saber", "style": "headband"},
	"assassin": {"robe": Color(0.15, 0.15, 0.19), "trim": Color(0.5, 0.1, 0.12), "hair": Color(0.05, 0.05, 0.06), "pants": Color(0.08, 0.08, 0.1), "weapon": "dart", "style": "mask"},
	"boss_bandit": {"robe": Color(0.5, 0.14, 0.12), "trim": Color(0.85, 0.65, 0.25), "hair": Color(0.1, 0.08, 0.06), "pants": Color(0.2, 0.12, 0.1), "weapon": "big_saber", "style": "beard"},
	"boss_snake": {"robe": Color(0.2, 0.45, 0.3), "trim": Color(0.6, 0.35, 0.65), "hair": Color(0.85, 0.85, 0.8), "pants": Color(0.15, 0.25, 0.18), "weapon": "staff", "style": "long"},
	"boss_demon": {"robe": Color(0.62, 0.08, 0.1), "trim": Color(0.95, 0.7, 0.2), "hair": Color(0.06, 0.04, 0.05), "pants": Color(0.12, 0.05, 0.06), "weapon": "claw", "style": "crown", "cape": Color(0.14, 0.04, 0.07)},
}

static var _flash := 0.0


static func _c(col: Color) -> Color:
	return col.lerp(Color.WHITE, _flash) if _flash > 0.0 else col


static func ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, seg := 18) -> void:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


static func _poly(ci: CanvasItem, pts: Array, col: Color, off := Vector2.ZERO) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(v + off)
	ci.draw_colored_polygon(p, _c(col))


## 繪製一個戰鬥／地圖角色。s 為縮放，facing 為 1（向右）或 -1（向左），flash 為受擊白光 0~1
static func draw_unit(ci: CanvasItem, kind: String, pos: Vector2, s: float, t: float, facing := 1, flash := 0.0) -> void:
	_flash = clampf(flash, 0.0, 1.0)
	if kind == "boss_demon":
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		ci.draw_circle(pos + Vector2(0, -28 * s), (30.0 + pulse * 6.0) * s, Color(1, 0.1, 0.1, 0.12 + pulse * 0.08))
	ci.draw_set_transform(pos, 0.0, Vector2(s * facing, s))
	match kind:
		"wolf":
			_wolf(ci, t)
		"snake":
			_snake(ci, t)
		_:
			_human(ci, PAL.get(kind, PAL.hero), t)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_flash = 0.0


static func _human(ci: CanvasItem, p: Dictionary, t: float) -> void:
	var b := Vector2(0, sin(t * 3.0) * 1.2)
	ellipse(ci, Vector2.ZERO, Vector2(16, 5), Color(0, 0, 0, 0.28))
	if p.has("cape"):
		_poly(ci, [Vector2(-9, -36), Vector2(9, -36), Vector2(16 + sin(t * 4.0) * 2.0, -2), Vector2(-20 + sin(t * 4.0) * 2.0, -2)], p.cape, b)
	# 腿與鞋
	ci.draw_rect(Rect2(-8, -12, 6, 11), _c(p.pants))
	ci.draw_rect(Rect2(2, -12, 6, 11), _c(p.pants))
	ci.draw_rect(Rect2(-9, -3, 8, 3), _c(Color(0.12, 0.09, 0.07)))
	ci.draw_rect(Rect2(1, -3, 9, 3), _c(Color(0.12, 0.09, 0.07)))
	# 長髮披在身後
	if p.style == "long":
		ci.draw_rect(Rect2(Vector2(-10, -50) + b, Vector2(14, 25)), _c(p.hair))
	# 後手
	ci.draw_line(Vector2(-8, -33) + b, Vector2(-13, -20) + b, _c(p.robe.darkened(0.25)), 5.0)
	ci.draw_circle(Vector2(-13, -19) + b, 2.8, _c(SKIN))
	# 長袍、下襬、衣襟、腰帶
	_poly(ci, [Vector2(-13, -9), Vector2(13, -9), Vector2(9, -37), Vector2(-9, -37)], p.robe, b)
	_poly(ci, [Vector2(-13, -9), Vector2(13, -9), Vector2(12, -13), Vector2(-12, -13)], p.robe.darkened(0.25), b)
	ci.draw_line(Vector2(-6, -37) + b, Vector2(3, -26) + b, _c(p.trim), 2.0)
	ci.draw_line(Vector2(6, -37) + b, Vector2(-1, -28) + b, _c(p.trim), 2.0)
	ci.draw_rect(Rect2(Vector2(-10, -27) + b, Vector2(20, 4)), _c(p.trim.darkened(0.15)))
	# 頭部
	ci.draw_rect(Rect2(Vector2(-2.5, -40) + b, Vector2(5, 4)), _c(SKIN.darkened(0.1)))
	ci.draw_circle(Vector2(-0.5, -46) + b, 8.6, _c(p.hair))
	ci.draw_circle(Vector2(1.5, -43.5) + b, 7.0, _c(SKIN))
	var eye: Color = Color(0.9, 0.15, 0.1) if p.style == "crown" else Color(0.1, 0.08, 0.08)
	ci.draw_circle(Vector2(3.0, -44.5) + b, 1.1, _c(eye))
	ci.draw_circle(Vector2(6.6, -44.5) + b, 1.1, _c(eye))
	ci.draw_line(Vector2(4, -40.5) + b, Vector2(6.5, -40.5) + b, _c(Color(0.6, 0.3, 0.25)), 1.0)
	match p.style:
		"topknot":
			ci.draw_circle(Vector2(-1, -55.5) + b, 3.8, _c(p.hair))
			ci.draw_line(Vector2(-4, -53) + b, Vector2(-9, -50) + b, _c(p.trim), 1.5)
		"long":
			ci.draw_circle(Vector2(-6, -51) + b, 4.0, _c(p.hair))
			ci.draw_circle(Vector2(-3, -54) + b, 1.6, _c(Color(1.0, 0.75, 0.3)))
		"headband":
			ci.draw_rect(Rect2(Vector2(-9, -51) + b, Vector2(17, 3)), _c(Color(0.8, 0.12, 0.1)))
			ci.draw_line(Vector2(-8, -50) + b, Vector2(-15, -45 + sin(t * 5.0)) + b, _c(Color(0.8, 0.12, 0.1)), 2.0)
		"mask":
			ci.draw_rect(Rect2(Vector2(-1, -42.5) + b, Vector2(9.5, 5.5)), _c(Color(0.05, 0.05, 0.06)))
			ci.draw_rect(Rect2(Vector2(-9, -51) + b, Vector2(17, 2)), _c(p.trim))
		"beard":
			_poly(ci, [Vector2(-1, -41), Vector2(9, -41), Vector2(6, -32), Vector2(1, -33)], p.hair, b)
			ci.draw_line(Vector2(2, -47) + b, Vector2(5, -46.5) + b, _c(p.hair), 2.0)
			ci.draw_line(Vector2(6, -46.5) + b, Vector2(8.5, -47) + b, _c(p.hair), 2.0)
		"crown":
			_poly(ci, [Vector2(-6, -52), Vector2(-10, -63), Vector2(-2, -54)], p.trim, b)
			_poly(ci, [Vector2(3, -54), Vector2(8, -64), Vector2(8, -52)], p.trim, b)
	# 前手與兵器
	var hand := Vector2(15, -22) + b
	ci.draw_line(Vector2(8, -33) + b, hand, _c(p.robe.darkened(0.08)), 5.0)
	_weapon(ci, p.weapon, hand, t)
	ci.draw_circle(hand, 2.8, _c(SKIN))


static func _weapon(ci: CanvasItem, w: String, hand: Vector2, t: float) -> void:
	var steel := _c(Color(0.86, 0.9, 0.96))
	match w:
		"sword":
			var dir := Vector2(0.5, -0.866)
			var perp := Vector2(0.866, 0.5)
			ci.draw_line(hand - dir * 4.0, hand + dir * 28.0, steel, 2.5)
			ci.draw_line(hand + dir * 3.0, hand + dir * 27.0, _c(Color.WHITE), 0.8)
			ci.draw_line(hand + dir * 2.0 - perp * 4.5, hand + dir * 2.0 + perp * 4.5, _c(Color(0.85, 0.65, 0.25)), 2.5)
			ci.draw_line(hand - dir * 4.0, hand - dir * 7.0, _c(Color(0.75, 0.15, 0.15)), 1.5)
		"saber":
			ci.draw_polyline(PackedVector2Array([hand, hand + Vector2(8, -12), hand + Vector2(13, -24)]), steel, 4.0)
			ci.draw_line(hand + Vector2(-2, -1), hand + Vector2(3, 2), _c(Color(0.5, 0.3, 0.15)), 3.0)
		"big_saber":
			_poly(ci, [hand + Vector2(0, -3), hand + Vector2(9, -28), hand + Vector2(19, -30), hand + Vector2(7, 0)], Color(0.82, 0.85, 0.9))
			ci.draw_line(hand + Vector2(0, -3), hand + Vector2(9, -28), _c(Color(0.4, 0.4, 0.45)), 2.0)
			ci.draw_circle(hand + Vector2(4, -10), 1.6, _c(Color(0.85, 0.65, 0.25)))
		"dart":
			for o in [Vector2(6, -4), Vector2(9, 2)]:
				_poly(ci, [hand + o + Vector2(0, -3), hand + o + Vector2(2, 0), hand + o + Vector2(0, 3), hand + o + Vector2(-2, 0)], Color(0.8, 0.82, 0.86))
		"staff":
			ci.draw_line(hand + Vector2(-1, 12), hand + Vector2(2, -36), _c(Color(0.45, 0.3, 0.18)), 3.0)
			ci.draw_circle(hand + Vector2(2, -38), 4.0, _c(Color(0.3, 0.7, 0.3)))
			ci.draw_circle(hand + Vector2(3.5, -39), 1.0, _c(Color(1, 0.9, 0.1)))
		"claw":
			var r := 6.0 + sin(t * 6.0) * 1.5
			ci.draw_circle(hand, r + 3.0, Color(1, 0.2, 0.1, 0.25))
			ci.draw_circle(hand, r, Color(1, 0.35, 0.15, 0.55))


static func _wolf(ci: CanvasItem, t: float) -> void:
	var b := sin(t * 4.0)
	ellipse(ci, Vector2.ZERO, Vector2(20, 5), Color(0, 0, 0, 0.28))
	var fur := Color(0.52, 0.52, 0.55)
	var dark := fur.darkened(0.35)
	_poly(ci, [Vector2(-15, -18), Vector2(-28, -27 + b * 2.0), Vector2(-25, -20), Vector2(-14, -13)], dark)
	for x in [-12, -6, 6, 11]:
		ci.draw_rect(Rect2(x - 2, -10, 4, 10), _c(dark))
	ellipse(ci, Vector2(0, -15 + b * 0.5), Vector2(17, 8), _c(fur))
	ellipse(ci, Vector2(0, -11 + b * 0.5), Vector2(12, 3.5), _c(fur.lightened(0.25)))
	var h := Vector2(0, b)
	ci.draw_circle(Vector2(15, -21) + h, 7.0, _c(fur))
	_poly(ci, [Vector2(19, -24), Vector2(29, -19), Vector2(28, -15.5), Vector2(18, -15)], fur.lightened(0.1), h)
	_poly(ci, [Vector2(10, -26), Vector2(11, -35), Vector2(15, -27)], dark, h)
	_poly(ci, [Vector2(15, -27), Vector2(18, -35), Vector2(19.5, -25)], dark, h)
	ci.draw_circle(Vector2(18, -23) + h, 1.5, _c(Color(1, 0.85, 0.2)))
	ci.draw_circle(Vector2(28.5, -18) + h, 1.5, _c(Color(0.05, 0.05, 0.05)))


static func _snake(ci: CanvasItem, t: float) -> void:
	ellipse(ci, Vector2(0, -2), Vector2(20, 5), Color(0, 0, 0, 0.25))
	var pts := PackedVector2Array()
	for i in 13:
		var x := -20.0 + i * 3.0
		pts.append(Vector2(x, -7.0 + sin(x * 0.28 + t * 4.0) * 4.0))
	var head := pts[pts.size() - 1] + Vector2(6, -7)
	ci.draw_polyline(pts, _c(Color(0.25, 0.55, 0.2)), 8.0, true)
	ci.draw_line(pts[pts.size() - 1], head, _c(Color(0.25, 0.55, 0.2)), 7.0)
	ci.draw_polyline(pts, _c(Color(0.75, 0.8, 0.35)), 2.5, true)
	ellipse(ci, head, Vector2(7, 5), _c(Color(0.22, 0.5, 0.18)))
	ci.draw_line(head + Vector2(6, 1), head + Vector2(12, 2 + sin(t * 12.0)), _c(Color(0.9, 0.15, 0.2)), 1.5)
	ci.draw_circle(head + Vector2(2, -2), 1.4, _c(Color(1, 0.9, 0.1)))


# ---------- 景物 ----------

static func tree(ci: CanvasItem, base: Vector2, s: float, col := Color(0.18, 0.42, 0.22)) -> void:
	ci.draw_rect(Rect2(base + Vector2(-2, -8) * s, Vector2(4, 8) * s), Color(0.4, 0.26, 0.14))
	ci.draw_circle(base + Vector2(-5, -11) * s, 6.0 * s, col.darkened(0.15))
	ci.draw_circle(base + Vector2(5, -11) * s, 6.0 * s, col.darkened(0.1))
	ci.draw_circle(base + Vector2(0, -16) * s, 8.0 * s, col)
	ci.draw_circle(base + Vector2(-2, -19) * s, 3.5 * s, col.lightened(0.2))


static func pine(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	ci.draw_rect(Rect2(base + Vector2(-2, -10) * s, Vector2(4, 10) * s), col.darkened(0.3))
	for i in 3:
		var y := -8.0 - i * 9.0
		var w := 15.0 - i * 4.0
		_poly(ci, [base + Vector2(-w, y) * s, base + Vector2(w, y) * s, base + Vector2(0, y - 14.0) * s], col)


static func rock(ci: CanvasItem, c: Vector2, s: float) -> void:
	ellipse(ci, c + Vector2(0, 8) * s, Vector2(20, 6) * s, Color(0, 0, 0, 0.25))
	_poly(ci, [c + Vector2(-18, 8) * s, c + Vector2(-14, -6) * s, c + Vector2(-4, -14) * s, c + Vector2(10, -10) * s, c + Vector2(18, 2) * s, c + Vector2(14, 9) * s], Color(0.48, 0.47, 0.44))
	_poly(ci, [c + Vector2(-12, -5) * s, c + Vector2(-4, -12) * s, c + Vector2(6, -9) * s, c + Vector2(-2, -4) * s], Color(0.66, 0.65, 0.6))


static func mountain(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	_poly(ci, [base + Vector2(-19, 0) * s, base + Vector2(0, -30) * s, base + Vector2(19, 0) * s], col)
	_poly(ci, [base + Vector2(0, -30) * s, base + Vector2(19, 0) * s, base + Vector2(3, 0) * s], col.darkened(0.25))
	_poly(ci, [base + Vector2(-6.5, -20) * s, base + Vector2(0, -30) * s, base + Vector2(6.5, -20) * s, base + Vector2(2, -22) * s, base + Vector2(-2, -19) * s], Color(0.95, 0.96, 0.98))


static func _roof(ci: CanvasItem, base: Vector2, w: float, h: float, col: Color) -> void:
	_poly(ci, [base + Vector2(-w - 4, 1), base + Vector2(-w, -2), base + Vector2(-w * 0.55, -h), base + Vector2(w * 0.55, -h), base + Vector2(w, -2), base + Vector2(w + 4, 1), base + Vector2(0, -1)], col)
	ci.draw_line(base + Vector2(-w * 0.55, -h), base + Vector2(w * 0.55, -h), col.darkened(0.4), 2.0)


static func _house(ci: CanvasItem, base: Vector2, s: float, roof: Color) -> void:
	ci.draw_rect(Rect2(base + Vector2(-11, -12) * s, Vector2(22, 12) * s), Color(0.9, 0.84, 0.7))
	ci.draw_rect(Rect2(base + Vector2(-3, -8) * s, Vector2(6, 8) * s), Color(0.35, 0.2, 0.12))
	ci.draw_rect(Rect2(base + Vector2(-9, -9) * s, Vector2(4, 4) * s), Color(0.95, 0.75, 0.35))
	_roof(ci, base + Vector2(0, -11) * s, 13.0 * s, 9.0 * s, roof)


## 大地圖上的據點圖示，c 為格子中心
static func location(ci: CanvasItem, id: String, c: Vector2) -> void:
	ellipse(ci, c + Vector2(0, 12), Vector2(18, 5), Color(0, 0, 0, 0.25))
	match id:
		"village":
			_house(ci, c + Vector2(-7, 6), 0.85, Color(0.55, 0.18, 0.15))
			_house(ci, c + Vector2(9, 12), 0.75, Color(0.2, 0.32, 0.48))
			ci.draw_line(c + Vector2(15, -6), c + Vector2(15, -20), Color(0.4, 0.25, 0.15), 1.5)
			_poly(ci, [c + Vector2(15, -20), c + Vector2(23, -18), c + Vector2(15, -15)], Color(0.9, 0.85, 0.7))
		"temple":
			for i in 3:
				var y := 12.0 - i * 9.0
				var w := 11.0 - i * 2.5
				ci.draw_rect(Rect2(c + Vector2(-w * 0.7, y - 7), Vector2(w * 1.4, 7)), Color(0.72, 0.2, 0.15))
				_roof(ci, c + Vector2(0, y - 6), w, 5.0, Color(0.2, 0.36, 0.3))
			ci.draw_line(c + Vector2(0, -16), c + Vector2(0, -24), Color(0.95, 0.75, 0.3), 2.0)
			ci.draw_circle(c + Vector2(0, -25), 2.0, Color(0.95, 0.75, 0.3))
		"sword_hut":
			ci.draw_rect(Rect2(c + Vector2(-11, 0), Vector2(18, 11)), Color(0.62, 0.48, 0.3))
			ci.draw_rect(Rect2(c + Vector2(-5, 3), Vector2(6, 8)), Color(0.3, 0.2, 0.12))
			_poly(ci, [c + Vector2(-15, 1), c + Vector2(-2, -12), c + Vector2(11, 1)], Color(0.82, 0.7, 0.38))
			for i in 4:
				ci.draw_line(c + Vector2(-11 + i * 6, 0), c + Vector2(-4 + i * 3, -9), Color(0.65, 0.52, 0.25), 1.0)
			ci.draw_line(c + Vector2(14, 12), c + Vector2(14, -10), Color(0.88, 0.92, 0.98), 2.5)
			ci.draw_line(c + Vector2(10, -6), c + Vector2(18, -6), Color(0.85, 0.65, 0.25), 2.5)
		"fort":
			for i in 7:
				var x := -15.0 + i * 5.0
				_poly(ci, [c + Vector2(x - 2.3, 12), c + Vector2(x - 2.3, -4), c + Vector2(x, -8), c + Vector2(x + 2.3, -4), c + Vector2(x + 2.3, 12)], Color(0.45, 0.3, 0.17) if i % 2 == 0 else Color(0.38, 0.25, 0.14))
			ci.draw_rect(Rect2(c + Vector2(-4, 2), Vector2(8, 10)), Color(0.12, 0.08, 0.06))
			ci.draw_line(c + Vector2(10, -4), c + Vector2(10, -24), Color(0.3, 0.2, 0.1), 1.5)
			_poly(ci, [c + Vector2(10, -24), c + Vector2(22, -21), c + Vector2(10, -16)], Color(0.1, 0.1, 0.1))
			ci.draw_circle(c + Vector2(14, -20.5), 2.0, Color(0.85, 0.15, 0.1))
		"cave":
			_poly(ci, [c + Vector2(-18, 12), c + Vector2(-13, -6), c + Vector2(-3, -14), c + Vector2(9, -11), c + Vector2(18, 0), c + Vector2(18, 12)], Color(0.4, 0.38, 0.36))
			_poly(ci, [c + Vector2(-13, -6), c + Vector2(-3, -14), c + Vector2(4, -10), c + Vector2(-6, -5)], Color(0.55, 0.53, 0.5))
			ci.draw_circle(c + Vector2(0, 4), 7.0, Color(0.04, 0.04, 0.05))
			ci.draw_rect(Rect2(c + Vector2(-7, 4), Vector2(14, 8)), Color(0.04, 0.04, 0.05))
			ci.draw_circle(c + Vector2(-2, 3), 1.2, Color(0.5, 1, 0.3))
			ci.draw_circle(c + Vector2(2, 3), 1.2, Color(0.5, 1, 0.3))
		"peak":
			_poly(ci, [c + Vector2(-20, 12), c + Vector2(-2, -24), c + Vector2(20, 12)], Color(0.45, 0.18, 0.16))
			_poly(ci, [c + Vector2(-2, -24), c + Vector2(20, 12), c + Vector2(4, 12)], Color(0.32, 0.12, 0.12))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-6, 10), c + Vector2(-2, 0), c + Vector2(-5, -8), c + Vector2(-2, -18)]), Color(1, 0.45, 0.15), 1.5)
			ci.draw_line(c + Vector2(-2, -24), c + Vector2(-2, -34), Color(0.3, 0.2, 0.1), 1.5)
			_poly(ci, [c + Vector2(-2, -34), c + Vector2(9, -31), c + Vector2(-2, -27)], Color(0.85, 0.1, 0.1))
