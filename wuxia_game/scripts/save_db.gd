extends Node
## 進度資料庫（自動載入：SaveDB）
## 以 JSON 文件資料庫儲存在 user:// 目錄，分成兩張「表」：
##  - slots：存檔欄位（0 為自動存檔，1~3 為手動存檔），保存完整遊戲狀態
##  - history：每一次存檔都新增一筆進度紀錄（時間、事件、等級、地點、銀兩……）

const SLOT_COUNT := 4
const HISTORY_LIMIT := 200
const SLOT_NAMES := ["自動存檔", "進度一", "進度二", "進度三"]

var db_path := "user://jianghu_save_db.json"
var _db: Dictionary = {}


func _ready() -> void:
	load_db()


func _empty_db() -> Dictionary:
	return {"version": 1, "slots": {}, "history": []}


func load_db() -> void:
	_db = _empty_db()
	if not FileAccess.file_exists(db_path):
		return
	var f := FileAccess.open(db_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		if parsed.get("slots") is Dictionary:
			_db.slots = parsed.slots
		if parsed.get("history") is Array:
			_db.history = parsed.history


func reset() -> void:
	_db = _empty_db()
	_write()


func save_slot(slot: int, data: Dictionary, summary: Dictionary, event: String) -> bool:
	var now := Time.get_datetime_string_from_system(false, true)
	_db.slots[str(slot)] = {"saved_at": now, "summary": summary, "data": data}
	var rec := summary.duplicate()
	rec["time"] = now
	rec["slot"] = slot
	rec["event"] = event
	_db.history.append(rec)
	while _db.history.size() > HISTORY_LIMIT:
		_db.history.pop_front()
	return _write()


func has_slot(slot: int) -> bool:
	return _db.slots.get(str(slot)) is Dictionary


func load_slot(slot: int) -> Dictionary:
	var rec = _db.slots.get(str(slot))
	if rec is Dictionary and rec.get("data") is Dictionary:
		return rec.data.duplicate(true)
	return {}


func slot_label(slot: int) -> String:
	var rec = _db.slots.get(str(slot))
	if not (rec is Dictionary):
		return "%s：（空）" % SLOT_NAMES[slot]
	var s: Dictionary = rec.get("summary", {})
	return "%s：%s Lv%d　%s　%s" % [SLOT_NAMES[slot], s.get("name", "?"), int(s.get("lv", 1)), s.get("location", ""), str(rec.get("saved_at", "")).substr(5, 11)]


## 最新的紀錄排在最前面
func get_history(limit: int = 10) -> Array:
	var out: Array = []
	var h: Array = _db.history
	for i in range(h.size() - 1, maxi(-1, h.size() - 1 - limit), -1):
		out.append(h[i])
	return out


func history_count() -> int:
	return _db.history.size()


func _write() -> bool:
	var tmp := db_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("無法寫入存檔：%s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(_db, "\t"))
	f.close()
	# 先寫暫存檔再改名，避免寫到一半當機造成存檔毀損
	var dst := ProjectSettings.globalize_path(db_path)
	if FileAccess.file_exists(db_path):
		DirAccess.remove_absolute(dst)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), dst) == OK
