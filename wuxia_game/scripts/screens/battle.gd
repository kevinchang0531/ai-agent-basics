extends Node2D
## 戰棋式回合戰鬥：依身法決定出手順序，每回合先移動、再選擇武功／物品／休息／逃跑

const UI = preload("res://scripts/ui.gd")
const Art = preload("res://scripts/art.gd")
const MenuBox = preload("res://scripts/menu.gd")

const COLS := 10
const ROWS := 7
const CELL := 64
const ORIGIN := Vector2(160, 40)
const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const ENEMY_SPOTS := [Vector2i(8, 3), Vector2i(7, 1), Vector2i(7, 5), Vector2i(8, 0), Vector2i(8, 6)]

var main
var args := {}
var counts_playtime := true
var units: Array = []
var obstacles := {}
var order: Array = []
var turn_idx := -1
var round_no := 0
var cur: Dictionary = {}
var state := "busy"
var cursor := Vector2i.ZERO
var reach := {}
var targets: Array = []
var target_idx := 0
var orig_pos := Vector2i.ZERO
var menu: MenuBox = null
var skill_ids: Array = []
var item_ids: Array = []
var chosen := ""
var logs: Array = []
var floaters: Array = []
var effects: Array = []
var result := {}
var boss := ""
var t := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	boss = args.get("boss", "")
	_make_field()
	for i in Game.party.size():
		units.append(_unit_from_member(Game.party[i], Vector2i(1, 3 + (i * 2 if i < 2 else -2))))
	var enemies: Array = args.get("enemies", [])
	for i in enemies.size():
		var e := Game.make_enemy(enemies[i].id, int(enemies[i].zone))
		units.append(_unit_from_enemy(e, ENEMY_SPOTS[i % ENEMY_SPOTS.size()]))
	Audio.play_bgm("battle")
	var names: Array = []
	for u in units:
		if u.team == 1:
			names.append(u.name)
	_log("遭遇 " + "、".join(names) + "！")
	await get_tree().create_timer(0.7).timeout
	_new_round()


func _make_field() -> void:
	var tries := 0
	while obstacles.size() < 5 and tries < 50:
		tries += 1
		var c := Vector2i(rng.randi_range(3, 6), rng.randi_range(0, ROWS - 1))
		if not obstacles.has(c):
			obstacles[c] = "rock" if rng.randf() < 0.5 else "tree"


func _center(p: Vector2i) -> Vector2:
	return ORIGIN + Vector2(p) * CELL + Vector2(CELL, CELL) * 0.5


func _unit_from_member(m: Dictionary, p: Vector2i) -> Dictionary:
	var lv := {}
	for sid in m.skills:
		lv[sid] = int(m.skills[sid].lv)
	return {
		"name": m.name, "team": 0, "kind": m.kind, "hp": maxi(1, int(m.hp)), "max_hp": int(m.max_hp),
		"mp": int(m.mp), "max_mp": int(m.max_mp), "atk": int(m.atk), "def": int(m.def), "move": int(m.move),
		"agi": int(m.agi), "skills": m.skills.keys(), "skill_lv": lv, "pos": p, "draw_pos": _center(p),
		"lunge": Vector2.ZERO, "flash": 0.0, "alive": true, "member": m, "boss": false, "exp": 0, "gold": 0,
	}


func _unit_from_enemy(e: Dictionary, p: Vector2i) -> Dictionary:
	var lv := {}
	for sid in e.skills:
		lv[sid] = int(e.zone)
	return {
		"name": e.name, "team": 1, "kind": e.kind, "hp": e.hp, "max_hp": e.hp, "mp": 0, "max_mp": 0,
		"atk": e.atk, "def": e.def, "move": e.move, "agi": e.agi, "skills": e.skills, "skill_lv": lv,
		"pos": p, "draw_pos": _center(p), "lunge": Vector2.ZERO, "flash": 0.0, "alive": true,
		"member": null, "boss": e.boss, "exp": e.exp, "gold": e.gold,
	}


func _log(s: String) -> void:
	logs.append(s)
	while logs.size() > 4:
		logs.pop_front()


func _unit_at(c: Vector2i):
	for u in units:
		if u.alive and u.pos == c:
			return u
	return null


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS


func _dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _alive(team: int) -> Array:
	return units.filter(func(u): return u.alive and u.team == team)


## 可移動到的格子（不能穿過敵人或障礙物，可穿過隊友但不能停在隊友身上）
func _reachable(u: Dictionary) -> Dictionary:
	var dist := {u.pos: 0}
	var q: Array = [u.pos]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if dist[c] >= u.move:
			continue
		for d in DIRS:
			var n: Vector2i = c + d
			if not _in_grid(n) or dist.has(n) or obstacles.has(n):
				continue
			var o = _unit_at(n)
			if o != null and o.team != u.team:
				continue
			dist[n] = dist[c] + 1
			q.append(n)
	var res := {}
	for c in dist:
		var o = _unit_at(c)
		if o == null or is_same(o, u):
			res[c] = dist[c]
	return res


func _targets_for(u: Dictionary, sid: String, from: Vector2i) -> Array:
	var sk: Dictionary = Game.SKILLS[sid]
	var team: int = u.team if sk.get("heal", false) else 1 - u.team
	return _alive(team).filter(func(o): return _dist(from, o.pos) <= sk.range)


# ---------- 回合流程 ----------

func _new_round() -> void:
	round_no += 1
	order = units.filter(func(u): return u.alive)
	order.sort_custom(func(a, b): return a.agi > b.agi)
	turn_idx = -1
	_next_turn()


func _next_turn() -> void:
	if _check_end():
		return
	turn_idx += 1
	while turn_idx < order.size() and not order[turn_idx].alive:
		turn_idx += 1
	if turn_idx >= order.size():
		_new_round()
		return
	cur = order[turn_idx]
	if cur.team == 0:
		orig_pos = cur.pos
		cursor = cur.pos
		reach = _reachable(cur)
		state = "move"
	else:
		state = "enemy"
		_enemy_turn()


func _end_turn() -> void:
	menu = null
	state = "busy"
	await get_tree().create_timer(0.15).timeout
	_next_turn()


func _check_end() -> bool:
	if _alive(1).is_empty():
		_victory()
		return true
	if _alive(0).is_empty():
		_defeat()
		return true
	return false


# ---------- 玩家操作 ----------

func _unhandled_input(event: InputEvent) -> void:
	var k := UI.key(event)
	if k == "":
		return
	if k == "music":
		Audio.toggle_music()
		return
	match state:
		"move":
			_input_move(k)
		"menu", "skill", "item":
			if menu:
				menu.handle(k)
		"target":
			_input_target(k)
		"result":
			if k == "ok":
				_finish()


func _input_move(k: String) -> void:
	var d := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}
	if d.has(k):
		var n: Vector2i = cursor + d[k]
		if _in_grid(n):
			cursor = n
			Audio.play_sfx("select")
	elif k == "ok":
		if reach.has(cursor):
			Audio.play_sfx("confirm")
			if cursor != cur.pos:
				Audio.play_sfx("step")
			cur.pos = cursor
			_open_action_menu()
		else:
			Audio.play_sfx("error")
	elif k == "cancel":
		cursor = cur.pos


func _open_action_menu() -> void:
	state = "menu"
	menu = MenuBox.new()
	menu.title = cur.name + " 的行動"
	menu.options = ["武功", "物品", "休息（回復內力）", "逃跑"]
	menu.width = 240.0
	menu.on_choose = _on_action


func _on_action(i: int) -> void:
	match i:
		-1:
			cur.pos = orig_pos
			cursor = orig_pos
			menu = null
			state = "move"
		0:
			_open_skill_menu()
		1:
			_open_item_menu()
		2:
			var mp := maxi(4, int(cur.max_mp * 0.2))
			var hp := int(cur.max_hp * 0.05)
			cur.mp = mini(cur.max_mp, cur.mp + mp)
			cur.hp = mini(cur.max_hp, cur.hp + hp)
			_float(cur, "+%d 內力" % mp, UI.BLUE)
			_log("%s 運功調息，恢復了內力。" % cur.name)
			Audio.play_sfx("heal")
			_end_turn()
		3:
			_flee()


func _open_skill_menu(index := 0) -> void:
	state = "skill"
	skill_ids = cur.skills
	menu = MenuBox.new()
	menu.title = "武功　內力 %d/%d" % [cur.mp, cur.max_mp]
	menu.width = 380.0
	for sid in skill_ids:
		var sk: Dictionary = Game.SKILLS[sid]
		var tag: String = "療傷" if sk.get("heal", false) else "威力%d" % sk.power
		menu.options.append("%s %d重　%s　內力%d　距離%d" % [sk.name, int(cur.skill_lv.get(sid, 1)), tag, sk.mp, sk.range])
		menu.disabled.append(sk.mp > cur.mp)
	menu.index = index
	menu.on_choose = _on_skill


func _on_skill(i: int) -> void:
	if i < 0:
		_open_action_menu()
		return
	var sid: String = skill_ids[i]
	targets = _targets_for(cur, sid, cur.pos)
	if targets.is_empty():
		Audio.play_sfx("error")
		_log("「%s」的範圍內沒有目標。" % Game.SKILLS[sid].name)
		return
	chosen = sid
	target_idx = 0
	cursor = targets[0].pos
	state = "target"


func _input_target(k: String) -> void:
	match k:
		"up", "left":
			target_idx = wrapi(target_idx - 1, 0, targets.size())
			cursor = targets[target_idx].pos
			Audio.play_sfx("select")
		"down", "right":
			target_idx = wrapi(target_idx + 1, 0, targets.size())
			cursor = targets[target_idx].pos
			Audio.play_sfx("select")
		"ok":
			state = "busy"
			menu = null
			await _perform(cur, targets[target_idx], chosen)
			_end_turn()
		"cancel":
			_open_skill_menu(skill_ids.find(chosen))


func _open_item_menu() -> void:
	state = "item"
	item_ids = []
	menu = MenuBox.new()
	menu.title = "物品"
	menu.width = 320.0
	for id in Game.ITEMS:
		var n := int(Game.items.get(id, 0))
		item_ids.append(id)
		menu.options.append("%s × %d" % [Game.ITEMS[id].name, n])
		menu.disabled.append(n <= 0)
	menu.on_choose = _on_item


func _on_item(i: int) -> void:
	if i < 0:
		_open_action_menu()
		return
	var id: String = item_ids[i]
	var it: Dictionary = Game.ITEMS[id]
	Game.items[id] = int(Game.items[id]) - 1
	cur.hp = mini(cur.max_hp, cur.hp + int(it.hp))
	cur.mp = mini(cur.max_mp, cur.mp + int(it.mp))
	_float(cur, "+%d" % it.hp, UI.GREEN)
	_log("%s 服下%s。" % [cur.name, it.name])
	Audio.play_sfx("heal")
	_end_turn()


func _flee() -> void:
	if boss != "":
		Audio.play_sfx("error")
		_log("強敵當前，無路可退！")
		return
	if rng.randf() < 0.6:
		state = "busy"
		menu = null
		_log("施展輕功，成功脫身！")
		_sync_party(false)
		await get_tree().create_timer(0.6).timeout
		main.change_screen("world", {"message": "你施展輕功，脫離了戰鬥。"})
	else:
		_log("逃跑失敗！")
		Audio.play_sfx("error")
		_end_turn()


# ---------- 出招 ----------

func _perform(att: Dictionary, tgt: Dictionary, sid: String) -> void:
	var sk: Dictionary = Game.SKILLS[sid]
	if att.team == 0:
		att.mp -= int(sk.mp)
	var dir := (Vector2(tgt.pos) - Vector2(att.pos)).normalized()
	att.lunge = dir * 16.0
	effects.append({"type": "melee" if sk.range <= 1 else "ranged", "from": _center(att.pos), "to": _center(tgt.pos), "t": 0.0, "color": Color(sk.color)})
	Audio.play_sfx("slash")
	await get_tree().create_timer(0.2).timeout
	if sk.get("heal", false):
		var amount := Game.heal_amount(att, sid)
		tgt.hp = mini(tgt.max_hp, tgt.hp + amount)
		_float(tgt, "+%d" % amount, UI.GREEN)
		_log("%s 施展「%s」，%s 恢復 %d 點氣血。" % [att.name, sk.name, tgt.name, amount])
		Audio.play_sfx("heal")
	else:
		var r := Game.calc_damage(att, tgt, sid, rng)
		tgt.hp = maxi(0, tgt.hp - int(r.dmg))
		tgt.flash = 1.0
		_float(tgt, ("暴擊 " if r.crit else "") + "-%d" % r.dmg, Color(1, 0.85, 0.2) if r.crit else Color(1, 1, 1))
		_log("%s 使出「%s」，對 %s 造成 %d 點傷害%s" % [att.name, sk.name, tgt.name, r.dmg, "（暴擊！）" if r.crit else "。"])
		Audio.play_sfx("crit" if r.crit else "hit")
		if tgt.hp <= 0:
			tgt.alive = false
			_log("%s 倒下了！" % tgt.name)
	if att.team == 0 and att.member != null:
		var msg := Game.add_skill_use(att.member, sid)
		att.skill_lv[sid] = int(att.member.skills[sid].lv)
		if msg != "":
			_log(msg)
			Audio.play_sfx("levelup")
	await get_tree().create_timer(0.35).timeout


func _float(u: Dictionary, s: String, col: Color) -> void:
	floaters.append({"text": s, "pos": _center(u.pos) + Vector2(0, -50), "t": 0.0, "color": col})


# ---------- 敵方 AI ----------

## 找出從 from 出手時最好的攻擊：威力最高的武功，打血量最低的目標
func _find_attack(u: Dictionary, from: Vector2i) -> Dictionary:
	var best := {}
	var best_power := -1
	for sid in u.skills:
		var sk: Dictionary = Game.SKILLS[sid]
		var in_range := _targets_for(u, sid, from)
		if in_range.is_empty() or sk.power <= best_power:
			continue
		in_range.sort_custom(func(a, b): return a.hp < b.hp)
		best = {"skill": sid, "target": in_range[0]}
		best_power = sk.power
	return best


func _enemy_turn() -> void:
	await get_tree().create_timer(0.35).timeout
	var foes := _alive(0)
	var plan := _find_attack(cur, cur.pos)
	if plan.is_empty():
		var r := _reachable(cur)
		var best_cell: Vector2i = cur.pos
		var best_score := INF
		for c in r:
			var near := 999
			for f in foes:
				near = mini(near, _dist(c, f.pos))
			var score: float = float(near) + (0.0 if _find_attack(cur, c).is_empty() == false else 100.0) + r[c] * 0.01
			if score < best_score:
				best_score = score
				best_cell = c
		if best_cell != cur.pos:
			cur.pos = best_cell
			Audio.play_sfx("step")
			await get_tree().create_timer(0.3).timeout
		plan = _find_attack(cur, cur.pos)
	if not plan.is_empty():
		await _perform(cur, plan.target, plan.skill)
	_end_turn()


# ---------- 結算 ----------

func _sync_party(won: bool) -> void:
	for u in units:
		if u.team == 0:
			u.member.hp = maxi(1, u.hp) if won or u.alive else 1
			u.member.mp = u.mp


func _victory() -> void:
	state = "result"
	var exp_sum := 0
	var gold_sum := 0
	for u in units:
		if u.team == 1:
			exp_sum += int(u.exp)
			gold_sum += int(u.gold)
	_sync_party(true)
	var lines: Array = ["獲得經驗 %d　銀兩 %d" % [exp_sum, gold_sum]]
	Game.gold += gold_sum
	if rng.randf() < 0.3:
		Game.items["potion"] = int(Game.items.get("potion", 0)) + 1
		lines.append("拾獲 金創藥 × 1")
	match boss:
		"fort":
			Game.flags["fort_cleared"] = true
			Game.items["elixir"] = int(Game.items.get("elixir", 0)) + 2
			lines.append("取得第一枚「武林令」與 大還丹 × 2！")
		"cave":
			Game.flags["cave_cleared"] = true
			Game.items["elixir"] = int(Game.items.get("elixir", 0)) + 2
			lines.append("取得「武林令」與 大還丹 × 2！")
		"final":
			Game.flags["final_cleared"] = true
			lines.append("赤煉魔君伏誅，江湖重歸太平！")
	lines.append_array(Game.gain_exp(exp_sum))
	result = {"win": true, "lines": lines}
	Audio.stop_bgm()
	Audio.play_sfx("victory")


func _defeat() -> void:
	state = "result"
	result = {"win": false, "lines": ["眼前一黑……", "醒來時已被鎮民救回清風鎮，失去了一半的銀兩。"]}
	Audio.stop_bgm()
	Audio.play_sfx("defeat")


func _finish() -> void:
	state = "busy"
	if not result.win:
		Game.on_defeat()
		SaveDB.save_slot(0, Game.to_dict(), Game.summary(), "戰敗")
		main.change_screen("world", {"message": "你在清風鎮的客棧醒來，氣血已經恢復。"})
		return
	if boss == "final":
		main.change_screen("ending")
		return
	var event: String = {"fort": "擊敗黑風寨主", "cave": "擊敗毒蛇郎君"}.get(boss, "戰鬥勝利")
	SaveDB.save_slot(0, Game.to_dict(), Game.summary(), event)
	main.change_screen("world", {"message": event + "！（已自動存檔）"})


# ---------- 繪製 ----------

func _process(delta: float) -> void:
	t += delta
	for u in units:
		u.draw_pos = u.draw_pos.lerp(_center(u.pos), minf(1.0, delta * 12.0))
		u.lunge = u.lunge.lerp(Vector2.ZERO, minf(1.0, delta * 8.0))
		u.flash = maxf(0.0, u.flash - delta * 4.0)
	for f in floaters:
		f.t += delta
	floaters = floaters.filter(func(f): return f.t < 1.0)
	for e in effects:
		e.t += delta
	effects = effects.filter(func(e): return e.t < 0.4)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color(0.12, 0.14, 0.1))
	# 戰場地面
	for y in ROWS:
		for x in COLS:
			var r := Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL))
			var g: Color = Color(0.4, 0.58, 0.3) if (x + y) % 2 == 0 else Color(0.37, 0.55, 0.28)
			draw_rect(r, g)
			var h := hash(Vector2i(x, y))
			if h % 5 == 0:
				var p := r.position + Vector2(10 + h % 40, 20 + (h / 7) % 36)
				draw_line(p, p + Vector2(-3, -7), Color(0.28, 0.48, 0.22), 1.5)
				draw_line(p, p + Vector2(3, -8), Color(0.3, 0.52, 0.24), 1.5)
	draw_rect(Rect2(ORIGIN, Vector2(COLS, ROWS) * CELL), Color(0, 0, 0, 0.4), false, 3.0)
	# 可移動範圍／攻擊目標提示
	if state == "move":
		for c in reach:
			draw_rect(Rect2(ORIGIN + Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-2), Color(0.35, 0.6, 1.0, 0.28))
	if state == "skill" and menu and menu.index < skill_ids.size():
		var sk: Dictionary = Game.SKILLS[skill_ids[menu.index]]
		for y in ROWS:
			for x in COLS:
				if _dist(Vector2i(x, y), cur.pos) <= sk.range:
					draw_rect(Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL)).grow(-2), Color(1, 0.4, 0.3, 0.22))
	if state == "target":
		for o in targets:
			draw_rect(Rect2(ORIGIN + Vector2(o.pos) * CELL, Vector2(CELL, CELL)).grow(-2), Color(1, 0.3, 0.25, 0.3))
	for c in obstacles:
		var base := _center(c) + Vector2(0, 18)
		if obstacles[c] == "rock":
			Art.rock(self, _center(c) + Vector2(0, 6), 1.1)
		else:
			Art.tree(self, base, 1.8)
	# 角色（依 y 排序，前面的蓋住後面的）
	var sorted := units.filter(func(u): return u.alive)
	sorted.sort_custom(func(a, b): return a.draw_pos.y < b.draw_pos.y)
	for u in sorted:
		var s: float = 1.2 if u.boss else 0.95
		var feet: Vector2 = u.draw_pos + u.lunge + Vector2(0, 24)
		if is_same(u, cur) and state != "result":
			var bob := sin(t * 6.0) * 3.0
			draw_colored_polygon(PackedVector2Array([feet + Vector2(-7, -78 + bob), feet + Vector2(7, -78 + bob), feet + Vector2(0, -70 + bob)]), UI.GOLD)
			Art.ellipse(self, feet, Vector2(24, 8), Color(UI.GOLD, 0.35))
		Art.draw_unit(self, u.kind, feet, s, t + u.agi, 1 if u.team == 0 else -1, u.flash)
		var bar_w := 44.0
		UI.bar(self, Rect2(feet + Vector2(-bar_w * 0.5, -68 * s), Vector2(bar_w, 5)), float(u.hp) / u.max_hp, UI.RED if u.team == 1 else UI.GREEN)
	# 游標
	if state in ["move", "target"]:
		var cr := Rect2(ORIGIN + Vector2(cursor) * CELL, Vector2(CELL, CELL)).grow(-1 - sin(t * 8.0) * 1.5)
		draw_rect(cr, Color(1, 0.9, 0.35), false, 3.0)
		var hov = _unit_at(cursor)
		if hov != null:
			UI.text(self, Vector2(ORIGIN.x + cursor.x * CELL + CELL * 0.5, ORIGIN.y + cursor.y * CELL - 4), "%s %d/%d" % [hov.name, hov.hp, hov.max_hp], 14, UI.PAPER, HORIZONTAL_ALIGNMENT_CENTER, -1, 4)
	# 招式特效
	for e in effects:
		var k: float = e.t / 0.4
		var col: Color = e.color
		if e.type == "melee":
			var a0 := -PI * 0.75 + k * PI
			draw_arc(e.to, 26.0, a0, a0 + PI * 0.6, 14, Color(col, 1.0 - k), 5.0)
			draw_arc(e.to, 20.0, a0 + 0.2, a0 + PI * 0.5, 10, Color(1, 1, 1, 0.7 * (1.0 - k)), 2.0)
		else:
			var p: Vector2 = e.from.lerp(e.to, minf(1.0, k * 1.6))
			draw_line(e.from.lerp(e.to, maxf(0.0, k * 1.6 - 0.3)), p, Color(col, 0.6), 4.0)
			draw_circle(p, 6.0, col)
			draw_circle(p, 10.0, Color(col, 0.3))
	for f in floaters:
		var a: float = 1.0 - f.t
		UI.text(self, f.pos - Vector2(0, f.t * 36.0), f.text, 22, Color(f.color, a), HORIZONTAL_ALIGNMENT_CENTER, -1, 5)
	_draw_panel()
	if menu and state in ["menu", "skill", "item"]:
		menu.draw_at(self, Vector2(940 - menu.width, 470 - menu.get_height()))
	if state == "result":
		_draw_result()


func _draw_panel() -> void:
	var top := "第 %d 回合" % maxi(1, round_no)
	if not cur.is_empty() and state != "result":
		top += "　·　%s 行動中" % cur.name
	UI.text(self, Vector2(ORIGIN.x, 28), top, 18, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	var hint: String = {
		"move": "方向鍵選擇位置，Enter 確定移動（原地按 Enter 不移動）",
		"menu": "選擇行動，Esc 取消移動",
		"skill": "紅色為武功攻擊範圍，Esc 返回",
		"target": "方向鍵切換目標，Enter 出招，Esc 返回",
		"enemy": "敵方行動中……",
	}.get(state, "")
	UI.text(self, Vector2(800, 28), hint, 14, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	var r := Rect2(8, 496, 944, 136)
	UI.panel(self, r, 0.9)
	var y := 522.0
	for u in units:
		if u.team != 0:
			continue
		UI.text(self, Vector2(24, y), u.name, 17, UI.PAPER if u.alive else UI.DIM)
		UI.bar(self, Rect2(110, y - 13, 150, 10), float(u.hp) / u.max_hp, UI.GREEN)
		UI.text(self, Vector2(268, y - 3), "%d/%d" % [u.hp, u.max_hp], 13, UI.PAPER)
		UI.bar(self, Rect2(110, y + 1, 150, 7), float(u.mp) / maxi(1, u.max_mp), UI.BLUE)
		UI.text(self, Vector2(268, y + 9), "%d/%d" % [u.mp, u.max_mp], 12, UI.BLUE)
		y += 36.0
	UI.text(self, Vector2(24, 622), "金創藥 %d　大還丹 %d" % [int(Game.items.get("potion", 0)), int(Game.items.get("elixir", 0))], 14, UI.DIM)
	draw_line(Vector2(340, 506), Vector2(340, 622), Color(UI.GOLD, 0.4), 1.0)
	for i in logs.size():
		UI.text(self, Vector2(356, 526 + i * 27), logs[i], 16, UI.PAPER if i == logs.size() - 1 else UI.DIM, HORIZONTAL_ALIGNMENT_LEFT, 586)


func _draw_result() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color(0, 0, 0, 0.55))
	var lines: Array = result.lines
	var r := Rect2(230, 150, 500, 120 + lines.size() * 30)
	UI.panel(self, r)
	UI.text(self, Vector2(480, 205), "勝　利" if result.win else "敗　北", 40, UI.GOLD if result.win else UI.RED, HORIZONTAL_ALIGNMENT_CENTER, -1, 6)
	for i in lines.size():
		UI.text(self, Vector2(480, 250 + i * 30), lines[i], 18, UI.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	UI.text(self, Vector2(480, r.end.y - 14), "按 Enter 繼續", 15, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
