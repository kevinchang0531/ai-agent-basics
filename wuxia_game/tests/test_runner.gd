extends SceneTree
## 無頭自動測試：godot --headless --path wuxia_game -s res://tests/test_runner.gd
## 檢查地圖、角色成長、傷害公式、存讀檔資料庫與所有腳本能否編譯。

var failures := 0
var passed := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failures += 1
		printerr("  ✗ ", what)


func _initialize() -> void:
	print("== 江湖俠客行 自動測試 ==")
	var G = load("res://scripts/game.gd").new()
	_test_map(G)
	_test_growth(G)
	_test_combat(G)
	_test_save_roundtrip(G)
	_test_save_db(G)
	_test_scripts_compile()
	G.free()
	print("通過 %d 項，失敗 %d 項" % [passed, failures])
	quit(1 if failures > 0 else 0)


func _test_map(G) -> void:
	check(G.MAP.size() == G.MAP_H, "地圖列數")
	for row in G.MAP:
		check(row.length() == G.MAP_W, "地圖每列長度為 %d" % G.MAP_W)
	# 從清風鎮出發，所有據點都必須走得到
	var start: Vector2i = G.LOCATIONS.village.pos
	var seen := {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if not seen.has(n) and G.is_walkable(n):
				seen[n] = true
				q.append(n)
	for id in G.LOCATIONS:
		check(seen.has(G.LOCATIONS[id].pos), "據點可抵達：%s" % id)
	check(G.encounter_rate(G.LOCATIONS.village.pos) == 0.0, "城鎮內不會遇敵")


func _test_growth(G) -> void:
	G.new_game("測試俠", {"str": 20, "con": 20, "agi": 20, "wis": 20})
	var m: Dictionary = G.party[0]
	check(m.max_hp == 110 and m.max_mp == 60 and m.move == 4, "初始數值計算")
	var msgs: Array = G.gain_exp(G.exp_to_next(1))
	check(m.lv == 2 and msgs.size() == 1, "經驗足夠時升級")
	check(m.hp == m.max_hp, "升級後回滿氣血")
	G.recruit_companion()
	check(G.party.size() == 2 and G.party[1].lv == 2, "同伴加入並同步等級")
	var leveled := false
	for i in 20:
		if G.add_skill_use(m, "fist") != "":
			leveled = true
	check(leveled and m.skills.fist.lv > 1, "武功使用後會升重")


func _test_combat(G) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var e: Dictionary = G.make_enemy("wolf", 1)
	var att := {"atk": 20, "skill_lv": {"fist": 1}}
	for i in 50:
		var r: Dictionary = G.calc_damage(att, e, "fist", rng)
		check(r.dmg >= 1, "傷害至少為 1")
	check(G.make_enemy("wolf", 3).hp > e.hp, "高區域敵人更強")
	for z in [1, 2, 3]:
		var enc: Array = G.random_encounter(Vector2i(10, 10), rng)
		check(enc.size() >= 1, "隨機遇敵至少一名敵人")
	for b in ["fort", "cave", "final"]:
		check(G.boss_battle(b).size() == 3, "頭目戰編隊：%s" % b)


func _test_save_roundtrip(G) -> void:
	G.gold = 123
	G.flags["fort_cleared"] = true
	G.pos = Vector2i(7, 8)
	var text := JSON.stringify(G.to_dict())
	var G2 = load("res://scripts/game.gd").new()
	G2.from_dict(JSON.parse_string(text))
	check(G2.gold == 123 and G2.pos == Vector2i(7, 8), "存讀檔：銀兩與位置")
	check(G2.tokens() == 1, "存讀檔：旗標")
	check(typeof(G2.party[0].lv) == TYPE_INT, "存讀檔：數字轉回整數")
	check(G2.party.size() == 2 and G2.party[1].skills.has("spring_heal"), "存讀檔：同伴與武功")
	G2.free()


func _test_save_db(G) -> void:
	var db = load("res://scripts/save_db.gd").new()
	db.db_path = "user://test_save_db.json"
	db.reset()
	check(not db.has_slot(1), "新資料庫沒有存檔")
	check(db.save_slot(1, G.to_dict(), G.summary(), "測試存檔"), "寫入存檔")
	db.save_slot(0, G.to_dict(), G.summary(), "自動存檔")
	var db2 = load("res://scripts/save_db.gd").new()
	db2.db_path = "user://test_save_db.json"
	db2.load_db()
	check(db2.has_slot(1) and not db2.load_slot(1).is_empty(), "重新開啟資料庫後讀得到存檔")
	check(db2.history_count() == 2, "每次存檔都新增一筆紀錄")
	check(db2.get_history(1)[0].event == "自動存檔", "紀錄依時間由新到舊")
	check(db2.slot_label(1).contains("測試俠"), "存檔欄位摘要")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save_db.json"))
	db.free()
	db2.free()


func _test_scripts_compile() -> void:
	for p in ["res://scripts/main.gd", "res://scripts/audio.gd", "res://scripts/ui.gd", "res://scripts/menu.gd",
			"res://scripts/art.gd", "res://scripts/map_layer.gd", "res://scripts/screens/title.gd",
			"res://scripts/screens/create.gd", "res://scripts/screens/world.gd",
			"res://scripts/screens/battle.gd", "res://scripts/screens/ending.gd"]:
		var s = load(p)
		check(s != null and s.can_instantiate(), "腳本可編譯：%s" % p)
