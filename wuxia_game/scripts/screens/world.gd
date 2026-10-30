extends Node2D
## 大地圖：自由探索、隨機遇敵、拜訪據點，以及 Esc 系統選單（狀態、存讀檔）

const UI = preload("res://scripts/ui.gd")
const Art = preload("res://scripts/art.gd")
const MenuBox = preload("res://scripts/menu.gd")
const MapLayer = preload("res://scripts/map_layer.gd")

const T := 32

var main
var args := {}
var counts_playtime := true
var menus: Array = []
var draw_pos := Vector2.ZERO
var facing := 1
var prev_pos := Vector2i.ZERO
var water: Array = []
var t := 0.0
var age := 0.0
var move_cd := 0.0
var steps := 0
var toast := ""
var toast_t := 0.0
var rng := RandomNumberGenerator.new()
var hud := Node2D.new()  # 狀態面板獨立一層，角色走到底下時整體淡出


func _ready() -> void:
	rng.randomize()
	var layer := MapLayer.new()
	layer.z_index = -1
	add_child(layer)
	add_child(hud)
	hud.draw.connect(_draw_hud)
	draw_pos = _px(Game.pos)
	prev_pos = Game.pos
	for y in Game.MAP_H:
		for x in Game.MAP_W:
			if Game.tile_at(Vector2i(x, y)) == "~":
				water.append(Vector2(x, y) * T)
	Audio.play_bgm("world")
	if args.get("intro", false):
		_message("江湖傳聞", [
			"二十年前被逐出中原的魔教護法「赤煉魔君」重現江湖，",
			"盤踞東北的赤霞峰，以陣法封山，四處擄掠。",
			"相傳唯有集齊黑風寨與幽冥洞的兩枚「武林令」，",
			"才能破陣登峰。少俠初出茅廬，不妨先在清風鎮周圍歷練，",
			"再往北方青雲寺、劍廬拜師學藝。",
		])
		SaveDB.save_slot(0, Game.to_dict(), Game.summary(), "踏入江湖")
	elif args.has("message"):
		show_toast(str(args.message))


func _px(p: Vector2i) -> Vector2:
	return Vector2(p) * T


# ---------- 選單工具 ----------

func open_menu(title: String, lines: Array, options: Array, cb: Callable, width := 420.0) -> MenuBox:
	var m := MenuBox.new()
	m.title = title
	m.lines = lines
	m.options = options
	m.on_choose = cb
	m.width = width
	menus.append(m)
	return m


func close_menu() -> void:
	if not menus.is_empty():
		menus.pop_back()


func _message(title: String, lines: Array) -> void:
	open_menu(title, lines, ["確定"], func(_i): close_menu(), 560.0)


func show_toast(s: String) -> void:
	toast = s
	toast_t = 3.0


# ---------- 移動與遇敵 ----------

func _process(delta: float) -> void:
	t += delta
	age += delta
	toast_t = maxf(0.0, toast_t - delta)
	move_cd -= delta
	draw_pos = draw_pos.lerp(_px(Game.pos), minf(1.0, delta * 16.0))
	if menus.is_empty() and move_cd <= 0.0 and age > 0.2:
		var d := _held_dir()
		if d != Vector2i.ZERO:
			_try_move(d)
			move_cd = 0.14
	var under := Rect2(0, 0, 330, 60 + Game.party.size() * 40).has_point(draw_pos + Vector2(16, 16))
	hud.modulate.a = lerpf(hud.modulate.a, 0.2 if under else 1.0, minf(1.0, delta * 10.0))
	hud.visible = menus.is_empty()
	hud.queue_redraw()
	queue_redraw()


func _held_dir() -> Vector2i:
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		return Vector2i.UP
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		return Vector2i.DOWN
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		return Vector2i.LEFT
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _try_move(d: Vector2i) -> void:
	if d.x != 0:
		facing = d.x
	var target := Game.pos + d
	if not Game.is_walkable(target):
		return
	prev_pos = Game.pos
	Game.pos = target
	steps += 1
	Audio.play_sfx("step")
	var loc := Game.location_at(target)
	if loc != "":
		_enter_location(loc)
	elif steps >= 4 and rng.randf() < Game.encounter_rate(target):
		steps = 0
		_start_battle(Game.random_encounter(target, rng), "")


func _start_battle(enemies: Array, boss: String) -> void:
	Audio.play_sfx("slash")
	main.change_screen("battle", {"enemies": enemies, "boss": boss})


func _unhandled_input(event: InputEvent) -> void:
	if age < 0.2:
		return
	var k := UI.key(event)
	if k == "":
		return
	if k == "music":
		Audio.toggle_music()
		show_toast("背景音樂：" + ("開" if Audio.music_on else "關"))
		return
	if not menus.is_empty():
		menus.back().handle(k)
		return
	if k == "cancel":
		Audio.play_sfx("confirm")
		_open_system_menu()
	elif k == "ok":
		var loc := Game.location_at(Game.pos)
		if loc != "":
			_enter_location(loc)


# ---------- 系統選單 ----------

func _open_system_menu() -> void:
	open_menu("江湖選單", ["遊戲時間 %s　足跡 %d 筆" % [_fmt_time(Game.playtime), SaveDB.history_count()]],
		["角色狀態", "行囊", "儲存進度", "讀取進度", "背景音樂：" + ("開" if Audio.music_on else "關"), "回到標題", "返回"], _on_system, 360.0)


func _fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


func _on_system(i: int) -> void:
	match i:
		0:
			_open_status()
		1:
			var lines: Array = ["銀兩：%d 兩　武林令：%d / 2" % [Game.gold, Game.tokens()]]
			for id in Game.ITEMS:
				lines.append("%s × %d（%s）" % [Game.ITEMS[id].name, int(Game.items.get(id, 0)), _item_desc(id)])
			_message("行囊", lines)
		2:
			_open_save()
		3:
			_open_load()
		4:
			Audio.toggle_music()
			close_menu()
			_open_system_menu()
			menus.back().index = 4
		5:
			main.change_screen("title")
		_:
			close_menu()


func _item_desc(id: String) -> String:
	var it: Dictionary = Game.ITEMS[id]
	return "氣血 +%d" % it.hp + ("、內力 +%d" % it.mp if it.mp > 0 else "")


func _open_status() -> void:
	var lines: Array = []
	for m in Game.party:
		lines.append("【%s】Lv%d　經驗 %d / %d" % [m.name, m.lv, m.exp, Game.exp_to_next(m.lv)])
		lines.append("　氣血 %d/%d　內力 %d/%d　攻 %d　防 %d　移動 %d" % [m.hp, m.max_hp, m.mp, m.max_mp, m.atk, m.def, m.move])
		lines.append("　臂力 %d　根骨 %d　身法 %d　悟性 %d" % [m["str"], m.con, m.agi, m.wis])
		var sk: Array = []
		for sid in m.skills:
			sk.append("%s(%d重)" % [Game.SKILLS[sid].name, m.skills[sid].lv])
		lines.append("　武功：" + "、".join(sk))
	_message("角色狀態", lines)
	menus.back().width = 640.0


func _open_save() -> void:
	var opts: Array = []
	for s in range(1, SaveDB.SLOT_COUNT):
		opts.append(SaveDB.slot_label(s))
	opts.append("返回")
	open_menu("儲存進度", ["存檔會寫入進度資料庫，並新增一筆足跡紀錄。"], opts, _on_save, 560.0)


func _on_save(i: int) -> void:
	close_menu()
	if i < 0 or i >= SaveDB.SLOT_COUNT - 1:
		return
	close_menu()
	if SaveDB.save_slot(i + 1, Game.to_dict(), Game.summary(), "手動存檔"):
		Audio.play_sfx("coin")
		show_toast("已儲存至「%s」。" % SaveDB.SLOT_NAMES[i + 1])
	else:
		show_toast("存檔失敗！")


func _open_load() -> void:
	var opts: Array = []
	var dis: Array = []
	for s in SaveDB.SLOT_COUNT:
		opts.append(SaveDB.slot_label(s))
		dis.append(not SaveDB.has_slot(s))
	opts.append("返回")
	dis.append(false)
	var m := open_menu("讀取進度", [], opts, _on_load, 560.0)
	m.disabled = dis


func _on_load(i: int) -> void:
	if i < 0 or i >= SaveDB.SLOT_COUNT:
		close_menu()
		return
	var data := SaveDB.load_slot(i)
	if data.is_empty():
		return
	Game.from_dict(data)
	main.change_screen("world", {"message": "已讀取「%s」。" % SaveDB.SLOT_NAMES[i]})


# ---------- 據點 ----------

func _enter_location(id: String) -> void:
	match id:
		"village":
			open_menu("清風鎮", ["小鎮依山傍水，往來商旅絡繹不絕。"],
				["客棧歇息（10 兩，完全恢復）", "雜貨鋪", "酒館打聽消息", "離開"], _on_village)
		"temple":
			var learned := Game.knows_skill("cloud_palm")
			var m := open_menu("青雲寺", ["古寺鐘聲悠揚，方丈慈眉善目。"],
				["拜師學藝：流雲掌（40 兩）" + ("　已習得" if learned else ""), "靜坐調息（恢復內力）", "離開"], _on_temple)
			m.disabled = [learned, false, false]
		"sword_hut":
			var a := Game.knows_skill("wind_sword")
			var b := Game.knows_skill("frost_finger")
			var m := open_menu("劍廬", ["竹林深處，一位白髮劍客閉目撫劍。"],
				["學習清風劍法（120 兩，需 Lv3）" + ("　已習得" if a else ""), "學習寒冰指（200 兩，需 Lv5）" + ("　已習得" if b else ""), "離開"], _on_sword_hut)
			m.disabled = [a, b, false]
		"fort":
			if Game.flags.get("fort_cleared", false):
				_message("黑風寨", ["寨中已空無一人，只剩隨風飄動的破旗。"])
			else:
				open_menu("黑風寨", ["寨門前插滿刀槍，嘍囉高聲叫罵。", "（頭目戰：黑風寨主，建議 Lv3 以上）"], ["闖寨！", "暫且退下"], _on_boss.bind("fort"))
		"cave":
			if Game.flags.get("cave_cleared", false):
				_message("幽冥洞", ["洞中毒霧已散，石壁上刻著前人的劍痕。"])
			else:
				open_menu("幽冥洞", ["洞內陰風陣陣，傳來嘶嘶蛇鳴。", "（頭目戰：毒蛇郎君，建議 Lv4 以上）"], ["深入洞穴！", "暫且退下"], _on_boss.bind("cave"))
		"peak":
			if Game.tokens() < 2:
				Game.pos = prev_pos
				_message("赤霞峰", ["山道被魔教弟子以陣法封鎖，紅霧瀰漫。", "需集齊兩枚武林令方能破陣（目前 %d / 2）。" % Game.tokens()])
			else:
				open_menu("赤霞峰", ["兩枚武林令發出共鳴，陣法應聲而破。", "峰頂傳來赤煉魔君的狂笑……（最終決戰，建議 Lv6 以上）"], ["登峰決戰！", "再準備一下"], _on_boss.bind("final"))


func _on_village(i: int) -> void:
	match i:
		0:
			if Game.gold >= 10:
				Game.gold -= 10
				Game.heal_all()
				Audio.play_sfx("heal")
				SaveDB.save_slot(0, Game.to_dict(), Game.summary(), "客棧歇息")
				show_toast("一夜好眠，氣血與內力全部恢復（已自動存檔）。")
			else:
				Audio.play_sfx("error")
				show_toast("銀兩不足……掌櫃搖了搖頭。")
		1:
			_open_shop()
		2:
			_tavern()
		_:
			close_menu()


func _open_shop(index := 0) -> void:
	var opts: Array = []
	var ids: Array = Game.ITEMS.keys()
	for id in ids:
		var it: Dictionary = Game.ITEMS[id]
		opts.append("%s（%d 兩）持有 %d" % [it.name, it.price, int(Game.items.get(id, 0))])
	opts.append("返回")
	var m := open_menu("雜貨鋪　銀兩 %d" % Game.gold, ["金創藥恢復 45 氣血；大還丹恢復 150 氣血、50 內力。"], opts, _on_shop)
	m.index = index


func _on_shop(i: int) -> void:
	var ids: Array = Game.ITEMS.keys()
	close_menu()
	if i < 0 or i >= ids.size():
		return
	var it: Dictionary = Game.ITEMS[ids[i]]
	if Game.gold >= it.price:
		Game.gold -= it.price
		Game.items[ids[i]] = int(Game.items.get(ids[i], 0)) + 1
		Audio.play_sfx("coin")
		show_toast("買下了一份%s。" % it.name)
	else:
		Audio.play_sfx("error")
		show_toast("銀兩不足。")
	_open_shop(i)


func _tavern() -> void:
	if not Game.flags.get("companion", false) and Game.tokens() >= 1:
		open_menu("酒館", ["一位身背長劍的少女走來：", "「聽說你闖過了險地？我叫林小雨，", "　想與你一同去找赤煉魔君算帳！」"], ["歡迎同行！", "改日再說"], _on_recruit, 480.0)
		return
	var hints: Array
	if Game.tokens() == 0:
		hints = ["掌櫃：「東邊的黑風寨、東南的幽冥洞，", "　各藏著一枚武林令。」", "說書人：「北方青雲寺的方丈，願傳流雲掌給有緣人。」"]
	elif Game.tokens() == 1:
		hints = ["掌櫃：「還差一枚武林令，就能破赤霞峰的陣法了。」", "劍客：「劍廬的寒冰指可隔空傷人，對付毒物最好。」"]
	else:
		hints = ["掌櫃：「兩枚武林令都到手了？赤霞峰在東北方，", "　務必帶足金創藥與大還丹！」"]
	_message("酒館", hints)


func _on_recruit(i: int) -> void:
	close_menu()
	if i == 0:
		Game.recruit_companion()
		Audio.play_sfx("levelup")
		show_toast("林小雨加入了隊伍！她會「回春訣」替同伴療傷。")


func _on_temple(i: int) -> void:
	match i:
		0:
			_learn("cloud_palm", 40, 1)
		1:
			for m in Game.party:
				m.mp = m.max_mp
			Audio.play_sfx("heal")
			show_toast("靜坐片刻，內力充盈。")
		_:
			close_menu()


func _on_sword_hut(i: int) -> void:
	match i:
		0:
			_learn("wind_sword", 120, 3)
		1:
			_learn("frost_finger", 200, 5)
		_:
			close_menu()


func _learn(sid: String, price: int, need_lv: int) -> void:
	if Game.party[0].lv < need_lv:
		Audio.play_sfx("error")
		show_toast("師父：「你的根基尚淺，到 Lv%d 再來吧。」" % need_lv)
	elif Game.gold < price:
		Audio.play_sfx("error")
		show_toast("拜師禮需要 %d 兩銀子。" % price)
	else:
		Game.gold -= price
		Game.learn_skill(sid)
		Audio.play_sfx("levelup")
		close_menu()
		show_toast("習得武功「%s」！%s" % [Game.SKILLS[sid].name, Game.SKILLS[sid].desc])


func _on_boss(i: int, boss: String) -> void:
	close_menu()
	if i == 0:
		_start_battle(Game.boss_battle(boss), boss)
	elif boss == "final":
		Game.pos = prev_pos


# ---------- 繪製 ----------

func _draw() -> void:
	# 水面波光
	for w in water:
		var o := sin(t * 2.0 + w.x * 0.05 + w.y * 0.08) * 3.0
		draw_line(w + Vector2(6 + o, 11), w + Vector2(14 + o, 11), Color(1, 1, 1, 0.25), 1.5)
		draw_line(w + Vector2(17 - o, 23), w + Vector2(26 - o, 23), Color(1, 1, 1, 0.18), 1.5)
	# 赤霞峰的紅霧
	var peak: Vector2i = Game.LOCATIONS.peak.pos
	if Game.tokens() < 2:
		draw_circle(_px(peak) + Vector2(16, 12), 26.0 + sin(t * 2.0) * 3.0, Color(1, 0.2, 0.15, 0.18))
	# 據點名稱
	for id in Game.LOCATIONS:
		var lp: Vector2i = Game.LOCATIONS[id].pos
		UI.text(self, _px(lp) + Vector2(16, -6), Game.LOCATIONS[id].name, 15, UI.PAPER, HORIZONTAL_ALIGNMENT_CENTER, -1, 4)
	# 同伴跟在身後
	if Game.party.size() > 1:
		Art.draw_unit(self, Game.party[1].kind, draw_pos + Vector2(16 - facing * 12, 28), 0.42, t + 1.0, facing)
	Art.draw_unit(self, "hero", draw_pos + Vector2(16, 30), 0.5, t, facing)
	if toast_t > 0.0:
		var a := minf(1.0, toast_t * 2.0)
		var r := Rect2(180, 540, 600, 44)
		draw_rect(r, Color(0, 0, 0, 0.7 * a))
		draw_rect(r, Color(UI.GOLD, a), false, 1.5)
		UI.text(self, Vector2(480, 569), toast, 18, Color(UI.PAPER, a), HORIZONTAL_ALIGNMENT_CENTER)
	if not menus.is_empty():
		draw_rect(Rect2(0, 0, 960, 640), Color(0, 0, 0, 0.35))
		for m in menus:
			m.draw_centered(self)
	draw_rect(Rect2(0, 618, 960, 22), Color(0, 0, 0, 0.55))
	UI.text(self, Vector2(10, 634), "%s　｜　方向鍵/WASD 移動　Enter 互動　Esc 選單　M 音樂" % Game.region_name(Game.pos), 14, UI.DIM)


func _draw_hud() -> void:
	var r := Rect2(8, 8, 300, 26 + Game.party.size() * 40)
	UI.panel(hud, r, 0.8)
	var y := 30.0
	UI.text(hud, Vector2(20, y), "銀兩 %d　武林令 %d/2　金創藥 %d" % [Game.gold, Game.tokens(), int(Game.items.get("potion", 0))], 15, UI.GOLD)
	for m in Game.party:
		y += 18.0
		UI.text(hud, Vector2(20, y + 4), "%s Lv%d" % [m.name, m.lv], 15, UI.PAPER)
		UI.bar(hud, Rect2(130, y - 7, 160, 9), float(m.hp) / m.max_hp, UI.RED)
		UI.bar(hud, Rect2(130, y + 5, 160, 7), float(m.mp) / m.max_mp, UI.BLUE)
		y += 22.0
