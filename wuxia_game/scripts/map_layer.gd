extends Node2D
## 大地圖的靜態圖層：所有地形與據點只在建立時繪製一次

const Art = preload("res://scripts/art.gd")

const ROADISH := ["=", "B"]


func _draw() -> void:
	for y in Game.MAP_H:
		for x in Game.MAP_W:
			_tile(Vector2i(x, y))
	var T: int = Game.TILE
	for id in Game.LOCATIONS:
		var lp: Vector2i = Game.LOCATIONS[id].pos
		Art.location(self, id, (Vector2(lp) + Vector2(0.5, 0.5)) * T)


func _connects(p: Vector2i) -> bool:
	return Game.tile_at(p) in ROADISH or Game.location_at(p) != ""


func _tile(p: Vector2i) -> void:
	var T: int = Game.TILE
	var r := Rect2(Vector2(p) * T, Vector2(T, T))
	var c := r.get_center()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p)
	var grass := Color(0.43, 0.63, 0.32).lerp(Color(0.36, 0.56, 0.27), rng.randf())
	var ch := Game.tile_at(p)
	match ch:
		"~", "B":
			draw_rect(r, Color(0.2, 0.43, 0.63).lerp(Color(0.17, 0.38, 0.58), rng.randf()))
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if Game.tile_at(p + d) != "~" and Game.tile_at(p + d) != "B":
					var a := c + Vector2(d) * T * 0.5
					var side := Vector2(d.y, d.x) * T * 0.5
					draw_line(a - side, a + side, Color(0.86, 0.8, 0.58), 4.0)
			if ch == "B":
				for i in 5:
					draw_rect(Rect2(r.position + Vector2(3, 2 + i * 6), Vector2(T - 6, 4)), Color(0.55, 0.36, 0.2))
				draw_line(r.position + Vector2(3, 0), r.position + Vector2(3, T), Color(0.35, 0.22, 0.12), 2.0)
				draw_line(r.position + Vector2(T - 3, 0), r.position + Vector2(T - 3, T), Color(0.35, 0.22, 0.12), 2.0)
		"^":
			draw_rect(r, Color(0.46, 0.5, 0.34))
			var shade := Color(0.5, 0.46, 0.4).lerp(Color(0.42, 0.42, 0.44), rng.randf())
			Art.mountain(self, c + Vector2(rng.randf_range(-3, 3), 12), rng.randf_range(0.85, 1.1), shade)
		"T":
			draw_rect(r, grass.darkened(0.18))
			Art.tree(self, c + Vector2(-7, 2), 0.7, Color(0.16, 0.4, 0.2))
			Art.tree(self, c + Vector2(7, 6), 0.75, Color(0.2, 0.45, 0.22))
			Art.tree(self, c + Vector2(0, 15), 0.8, Color(0.18, 0.42, 0.2))
		",":
			draw_rect(r, grass.darkened(0.05))
			for i in 6:
				var g := r.position + Vector2(rng.randf_range(4, T - 4), rng.randf_range(8, T - 2))
				draw_line(g, g + Vector2(-3, -7), Color(0.25, 0.5, 0.2), 1.5)
				draw_line(g, g + Vector2(2, -8), Color(0.3, 0.58, 0.24), 1.5)
		_:
			draw_rect(r, grass)
			if rng.randf() < 0.25:
				var f := r.position + Vector2(rng.randf_range(6, T - 6), rng.randf_range(6, T - 6))
				var petal: Color = [Color(1, 0.9, 0.4), Color(1, 0.6, 0.7), Color(0.95, 0.95, 1)][rng.randi() % 3]
				draw_circle(f, 1.8, petal)
			if ch == "=":
				var road := Color(0.78, 0.67, 0.47)
				draw_rect(Rect2(c - Vector2(9, 9), Vector2(18, 18)), road)
				for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if _connects(p + d):
						var e := c + Vector2(d) * T * 0.25
						draw_rect(Rect2(e - Vector2(9, 9) + Vector2(d) * 4.5, Vector2(18, 18)), road)
				draw_circle(c + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)), 1.2, road.darkened(0.25))
