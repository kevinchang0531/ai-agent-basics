extends SceneTree
## 實機遊玩冒煙測試：載入主場景，模擬鍵盤操作走過 標題 → 創角 → 大地圖 → 存檔 → 戰鬥，並截圖。
## 需要顯示環境：godot --path wuxia_game -s res://tests/smoke_play.gd -- <截圖資料夾>

var out_dir := "user://smoke"
var main: Node


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _key(code: Key, hold := 0.08) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(hold)
	var r := e.duplicate()
	r.pressed = false
	Input.parse_input_event(r)
	await _wait(0.25)


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
	print("截圖：", shot_name, "　畫面：", main.current.get_script().resource_path.get_file())


func _run() -> void:
	await _wait(1.0)
	while not root.get_node("Audio").is_ready():
		await _wait(0.5)
	print("背景音樂合成完成")
	await _shot("1_title")
	await _key(KEY_ENTER)                 # 新的江湖
	await _wait(0.4)
	await _key(KEY_ENTER)                 # 確認姓名
	await _key(KEY_R)                     # 重新擲骰
	await _shot("2_create")
	await _key(KEY_ENTER)                 # 踏入江湖
	await _wait(0.5)
	await _shot("3_world_intro")
	await _key(KEY_ENTER)                 # 關閉開場說明
	await _key(KEY_ENTER)                 # 站在清風鎮上：開啟城鎮選單
	await _shot("4_village")
	await _key(KEY_ESCAPE)
	await _key(KEY_RIGHT, 0.6)            # 往東走幾步
	await _key(KEY_UP, 0.3)
	var game = root.get_node("Game")
	print("目前位置：", game.pos, "　畫面：", main.current.get_script().resource_path.get_file())
	if main.current.get_script().resource_path.ends_with("world.gd"):
		await _key(KEY_ESCAPE)            # 系統選單
		await _key(KEY_DOWN)
		await _key(KEY_DOWN)
		await _key(KEY_ENTER)             # 儲存進度
		await _key(KEY_ENTER)             # 進度一
		print("進度一已存檔：", root.get_node("SaveDB").has_slot(1))
		await _shot("5_world_saved")
	# 直接進入一場戰鬥（避免依賴隨機遇敵）
	main.change_screen("battle", {"enemies": [{"id": "wolf", "zone": 1}, {"id": "bandit", "zone": 1}], "boss": ""})
	await _wait(1.5)
	await _shot("6_battle_move")
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)                 # 移動
	await _key(KEY_ENTER)                 # 武功
	await _shot("7_battle_skill")
	await _key(KEY_ESCAPE)                # 取消（若已開選單）
	# 自動作戰：游標移到敵人身旁的格子，再以真實按鍵出招
	var b = main.current
	for i in 80:
		await _wait(0.4)
		if b.state == "result":
			break
		if b.state == "menu" or b.state == "item" or b.state == "skill":
			await _key(KEY_ESCAPE)
			continue
		if b.state != "move":
			continue
		var best = b.cur.pos
		var best_d := 999
		for c in b.reach:
			for e in b._alive(1):
				var d: int = b._dist(c, e.pos)
				if d < best_d:
					best_d = d
					best = c
		b.cursor = best
		await _key(KEY_ENTER)             # 移動
		await _key(KEY_ENTER)             # 武功
		await _key(KEY_ENTER)             # 第一招
		if b.state == "target":
			if i == 0:
				await _shot("7_battle_target")
			await _key(KEY_ENTER)
		else:
			await _key(KEY_ESCAPE)
			await _key(KEY_DOWN)
			await _key(KEY_DOWN)
			await _key(KEY_ENTER)         # 休息
	await _shot("8_battle_later")
	print("戰鬥紀錄：", main.current.get("logs"))
	print("戰鬥結果：", main.current.get("result"))
	await _key(KEY_ENTER)
	await _wait(0.5)
	print("回到畫面：", main.current.get_script().resource_path.get_file(), "　最新足跡：", root.get_node("SaveDB").get_history(1))
	await _shot("9_after_battle")
	print("冒煙測試完成")
	quit(0)
