extends Node
## 遊戲狀態與規則（自動載入：Game）
## 地圖、武功、敵人、物品等資料集中在這裡，方便調整平衡。

const TILE := 32
const MAP_W := 30
const MAP_H := 20

# 地圖圖例：^ 山　~ 水　T 樹林　, 草叢　. 草地　= 道路　B 橋
const MAP := [
	"^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^",
	"^TTTT,,,....^^^^^..TTT^^^^^^^^",
	"^TT...=====..^^^.....T^^^^..^^",
	"^T.==.,,,,=====.====..^^^.=.^^",
	"^T..=.,,TT,,,,=====.=..^^=..^^",
	"^,,.=..TTT,,,..,,,..==.^.=..^^",
	"^,..=....TT,,.......,====,=.^^",
	"^...=..~~~~.....TT.....,=,..T^",
	"^..=..~~~~~B~...,,TTT..,,..TT^",
	"^..=..~~~~~=~~...,,TT.,,..,.T^",
	"^..=..~~~~~=~~~.......,,,,...^",
	"^,.=...~~~~=~~......TT.......^",
	"^,,=.......=.......TTT..^^^..^",
	"^,.=.......=........T..^^^^..^",
	"^..=.......=..,,.......^^....^",
	"^.T=========================.^",
	"^TT.......,,,.....TT....,=...^",
	"^TTT..,,,.....,,,.TTT...^^,..^",
	"^TTTT.......TTTT....,,..^^^^.^",
	"^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^",
]

const LOCATIONS := {
	"village": {"name": "清風鎮", "pos": Vector2i(4, 15)},
	"temple": {"name": "青雲寺", "pos": Vector2i(3, 4)},
	"sword_hut": {"name": "劍廬", "pos": Vector2i(16, 3)},
	"fort": {"name": "黑風寨", "pos": Vector2i(24, 7)},
	"cave": {"name": "幽冥洞", "pos": Vector2i(25, 16)},
	"peak": {"name": "赤霞峰", "pos": Vector2i(26, 2)},
}

# power：威力　mp：內力消耗　range：攻擊距離（曼哈頓距離）
const SKILLS := {
	"fist": {"name": "基本拳腳", "power": 6, "mp": 0, "range": 1, "color": "#f1e3bd", "desc": "人人皆會的入門拳腳。"},
	"cloud_palm": {"name": "流雲掌", "power": 14, "mp": 5, "range": 1, "color": "#9fd3ff", "desc": "掌勢如行雲流水。"},
	"wind_sword": {"name": "清風劍法", "power": 22, "mp": 9, "range": 2, "color": "#b8ffcf", "desc": "劍氣可及兩步之外。"},
	"frost_finger": {"name": "寒冰指", "power": 19, "mp": 8, "range": 3, "color": "#d6f4ff", "desc": "凝寒成冰，隔空傷敵。"},
	"spring_heal": {"name": "回春訣", "power": 26, "mp": 8, "range": 2, "color": "#7dffa0", "heal": true, "desc": "以內力為同伴療傷。"},
	"bite": {"name": "撕咬", "power": 6, "mp": 0, "range": 1, "color": "#ffffff"},
	"saber": {"name": "砍刀", "power": 9, "mp": 0, "range": 1, "color": "#ffd27f"},
	"venom": {"name": "毒牙", "power": 9, "mp": 0, "range": 1, "color": "#a6ff6b"},
	"dart": {"name": "飛鏢", "power": 8, "mp": 0, "range": 3, "color": "#d0d0d0"},
	"heavy_saber": {"name": "開山刀", "power": 20, "mp": 0, "range": 1, "color": "#ff9a52"},
	"snake_staff": {"name": "靈蛇杖", "power": 16, "mp": 0, "range": 2, "color": "#7cff9a"},
	"blood_palm": {"name": "赤煉掌", "power": 26, "mp": 0, "range": 2, "color": "#ff4a4a"},
}

const ENEMIES := {
	"wolf": {"name": "野狼", "kind": "wolf", "hp": 32, "atk": 11, "def": 2, "agi": 22, "move": 4, "skills": ["bite"], "exp": 12, "gold": 2},
	"bandit": {"name": "山賊", "kind": "bandit", "hp": 42, "atk": 13, "def": 4, "agi": 14, "move": 3, "skills": ["saber"], "exp": 15, "gold": 12},
	"snake": {"name": "毒蛇", "kind": "snake", "hp": 28, "atk": 15, "def": 2, "agi": 18, "move": 3, "skills": ["venom"], "exp": 16, "gold": 3},
	"assassin": {"name": "黑衣刺客", "kind": "assassin", "hp": 58, "atk": 18, "def": 6, "agi": 26, "move": 4, "skills": ["saber", "dart"], "exp": 32, "gold": 25},
	"boss_fort": {"name": "黑風寨主", "kind": "boss_bandit", "hp": 180, "atk": 22, "def": 9, "agi": 16, "move": 3, "skills": ["heavy_saber", "saber"], "exp": 120, "gold": 150, "boss": true},
	"boss_cave": {"name": "毒蛇郎君", "kind": "boss_snake", "hp": 210, "atk": 25, "def": 10, "agi": 24, "move": 3, "skills": ["snake_staff", "venom"], "exp": 170, "gold": 200, "boss": true},
	"boss_final": {"name": "赤煉魔君", "kind": "boss_demon", "hp": 460, "atk": 32, "def": 14, "agi": 28, "move": 3, "skills": ["blood_palm", "heavy_saber"], "exp": 300, "gold": 0, "boss": true},
}

const ITEMS := {
	"potion": {"name": "金創藥", "hp": 45, "mp": 0, "price": 20},
	"elixir": {"name": "大還丹", "hp": 150, "mp": 50, "price": 60},
}

const ENCOUNTERS := {
	1: [["wolf"], ["wolf", "wolf"], ["bandit"], ["bandit", "wolf"]],
	2: [["bandit", "bandit"], ["snake", "wolf"], ["snake", "snake", "wolf"], ["assassin"]],
	3: [["assassin", "bandit"], ["assassin", "snake", "snake"], ["bandit", "bandit", "wolf"], ["assassin", "assassin"]],
}

# 每場頭目戰：[敵人 id, 區域強度]
const BOSS_BATTLES := {
	"fort": [["boss_fort", 1], ["bandit", 2], ["bandit", 2]],
	"cave": [["boss_cave", 1], ["snake", 2], ["snake", 2]],
	"final": [["boss_final", 1], ["assassin", 3], ["assassin", 3]],
}

const COMPANION := {"name": "林小雨", "kind": "heroine", "str": 17, "con": 16, "agi": 28, "wis": 26, "skills": ["fist", "wind_sword", "spring_heal"]}

const STAT_MIN := 12
const STAT_MAX := 30
const INT_KEYS := ["lv", "exp", "str", "con", "agi", "wis", "hp", "mp", "max_hp", "max_mp", "atk", "def", "move"]

var party: Array = []
var pos := Vector2i(4, 15)
var gold := 0
var items: Dictionary = {}
var flags: Dictionary = {}
var playtime := 0.0


# ---------- 開局與角色 ----------

func roll_stats(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"str": rng.randi_range(STAT_MIN, STAT_MAX),
		"con": rng.randi_range(STAT_MIN, STAT_MAX),
		"agi": rng.randi_range(STAT_MIN, STAT_MAX),
		"wis": rng.randi_range(STAT_MIN, STAT_MAX),
	}


func new_game(hero_name: String, stats: Dictionary) -> void:
	party = [make_member(hero_name, "hero", stats, ["fist"])]
	pos = LOCATIONS.village.pos
	gold = 60
	items = {"potion": 3, "elixir": 0}
	flags = {}
	playtime = 0.0


func make_member(member_name: String, kind: String, base: Dictionary, skill_ids: Array) -> Dictionary:
	var m := {
		"name": member_name, "kind": kind, "lv": 1, "exp": 0,
		"str": int(base["str"]), "con": int(base.con), "agi": int(base.agi), "wis": int(base.wis),
		"skills": {},
	}
	for sid in skill_ids:
		m.skills[sid] = {"lv": 1, "uses": 0}
	recalc(m)
	m.hp = m.max_hp
	m.mp = m.max_mp
	return m


func recalc(m: Dictionary) -> void:
	m.max_hp = 50 + m.con * 3 + (m.lv - 1) * 10
	m.max_mp = 20 + m.wis * 2 + (m.lv - 1) * 4
	m.atk = m["str"]
	m.def = int(m.con / 2.0)
	m.move = 3 + int(m.agi / 20.0)
	if m.has("hp"):
		m.hp = mini(int(m.hp), int(m.max_hp))
		m.mp = mini(int(m.mp), int(m.max_mp))


func level_up(m: Dictionary) -> void:
	m.lv += 1
	m["str"] += 2
	m.con += 1
	m.agi += 1
	m.wis += 1
	recalc(m)
	m.hp = m.max_hp
	m.mp = m.max_mp


func exp_to_next(lv: int) -> int:
	return 30 + lv * lv * 20


func gain_exp(amount: int) -> Array:
	var msgs: Array = []
	for m in party:
		m.exp += amount
		while m.exp >= exp_to_next(m.lv):
			m.exp -= exp_to_next(m.lv)
			level_up(m)
			msgs.append("%s 升到了第 %d 級！" % [m.name, m.lv])
	return msgs


func recruit_companion() -> void:
	var m := make_member(COMPANION.name, COMPANION.kind, COMPANION, COMPANION.skills)
	while m.lv < party[0].lv:
		level_up(m)
	party.append(m)
	flags["companion"] = true


func heal_all() -> void:
	for m in party:
		m.hp = m.max_hp
		m.mp = m.max_mp


func knows_skill(sid: String) -> bool:
	return party[0].skills.has(sid)


func learn_skill(sid: String) -> void:
	if not knows_skill(sid):
		party[0].skills[sid] = {"lv": 1, "uses": 0}


func tokens() -> int:
	return int(flags.get("fort_cleared", false)) + int(flags.get("cave_cleared", false))


# ---------- 武功與傷害 ----------

func skill_mult(lv: int) -> float:
	return 1.0 + 0.12 * (lv - 1)


## 使用武功後累積修為，升重時回傳提示文字
func add_skill_use(m: Dictionary, sid: String) -> String:
	var s: Dictionary = m.skills.get(sid, {})
	if s.is_empty() or s.lv >= 10:
		return ""
	s.uses += 1
	var need := maxi(2, 3 + int(s.lv) * 2 - int(m.wis / 15.0))
	if s.uses >= need:
		s.lv += 1
		s.uses = 0
		return "%s 的「%s」修為提升至第 %d 重！" % [m.name, SKILLS[sid].name, s.lv]
	return ""


func calc_damage(att: Dictionary, tgt: Dictionary, sid: String, rng: RandomNumberGenerator) -> Dictionary:
	var sk: Dictionary = SKILLS[sid]
	var lv: int = int(att.get("skill_lv", {}).get(sid, 1))
	var base: float = sk.power * skill_mult(lv) + att.atk * 0.9 - tgt.def * 0.7
	base *= rng.randf_range(0.88, 1.12)
	var crit := rng.randf() < 0.1
	if crit:
		base *= 1.6
	return {"dmg": maxi(1, roundi(base)), "crit": crit}


func heal_amount(att: Dictionary, sid: String) -> int:
	var sk: Dictionary = SKILLS[sid]
	var lv: int = int(att.get("skill_lv", {}).get(sid, 1))
	return roundi(sk.power * skill_mult(lv) + att.atk * 0.4)


func make_enemy(id: String, zone: int) -> Dictionary:
	var e: Dictionary = ENEMIES[id]
	var hp_mult := 1.0 + 0.35 * (zone - 1)
	var atk_mult := 1.0 + 0.18 * (zone - 1)
	return {
		"name": e.name, "kind": e.kind,
		"hp": int(e.hp * hp_mult), "atk": int(e.atk * atk_mult), "def": int(e.def + zone - 1),
		"agi": e.agi, "move": e.move, "skills": e.skills.duplicate(),
		"exp": int(e.exp * (1.0 + 0.5 * (zone - 1))), "gold": int(e.gold * (1.0 + 0.5 * (zone - 1))),
		"boss": e.get("boss", false), "zone": zone,
	}


# ---------- 地圖 ----------

func tile_at(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= MAP_W or p.y >= MAP_H:
		return "^"
	var row: String = MAP[p.y]
	return row[p.x]


func is_walkable(p: Vector2i) -> bool:
	return tile_at(p) not in ["^", "~"]


func location_at(p: Vector2i) -> String:
	for id in LOCATIONS:
		if LOCATIONS[id].pos == p:
			return id
	return ""


func encounter_rate(p: Vector2i) -> float:
	if location_at(p) != "":
		return 0.0
	match tile_at(p):
		",":
			return 0.14
		"T":
			return 0.12
		".":
			return 0.06
	return 0.0


func zone_at(p: Vector2i) -> int:
	var v: Vector2i = LOCATIONS.village.pos
	var d := absi(p.x - v.x) + absi(p.y - v.y)
	return clampi(1 + int(d / 12.0), 1, 3)


func random_encounter(p: Vector2i, rng: RandomNumberGenerator) -> Array:
	var zone := zone_at(p)
	var table: Array = ENCOUNTERS[zone]
	var pick: Array = table[rng.randi() % table.size()]
	return pick.map(func(id): return {"id": id, "zone": zone})


func boss_battle(boss: String) -> Array:
	var list: Array = BOSS_BATTLES[boss]
	return list.map(func(e): return {"id": e[0], "zone": e[1]})


func region_name(p: Vector2i) -> String:
	var best := ""
	var best_d := 9999
	for id in LOCATIONS:
		var lp: Vector2i = LOCATIONS[id].pos
		var d := absi(p.x - lp.x) + absi(p.y - lp.y)
		if d < best_d:
			best_d = d
			best = LOCATIONS[id].name
	return best if best_d == 0 else best + "附近"


func on_defeat() -> void:
	gold = int(gold / 2.0)
	pos = LOCATIONS.village.pos
	heal_all()


# ---------- 存讀檔 ----------

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"party": party.duplicate(true),
		"pos": [pos.x, pos.y],
		"gold": gold,
		"items": items.duplicate(),
		"flags": flags.duplicate(),
		"playtime": playtime,
	}


## JSON 讀回的數字都是浮點數，這裡統一轉回整數
func from_dict(d: Dictionary) -> void:
	party = []
	for raw in d.get("party", []):
		var m: Dictionary = raw.duplicate(true)
		for k in INT_KEYS:
			if m.has(k):
				m[k] = int(m[k])
		var skills := {}
		for sid in m.get("skills", {}):
			skills[sid] = {"lv": int(m.skills[sid].lv), "uses": int(m.skills[sid].uses)}
		m.skills = skills
		recalc(m)
		party.append(m)
	var p: Array = d.get("pos", [4, 15])
	pos = Vector2i(int(p[0]), int(p[1]))
	gold = int(d.get("gold", 0))
	items = {}
	var raw_items: Dictionary = d.get("items", {})
	for k in raw_items:
		items[k] = int(raw_items[k])
	flags = {}
	var raw_flags: Dictionary = d.get("flags", {})
	for k in raw_flags:
		flags[k] = bool(raw_flags[k])
	playtime = float(d.get("playtime", 0.0))


func summary() -> Dictionary:
	return {
		"name": party[0].name, "lv": party[0].lv, "location": region_name(pos),
		"gold": gold, "tokens": tokens(), "playtime": int(playtime),
	}
