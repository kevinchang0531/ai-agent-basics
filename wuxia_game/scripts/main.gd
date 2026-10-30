extends Node2D
## 主場景：負責切換標題、創角、大地圖、戰鬥與結局畫面

const SCREENS := {
	"title": preload("res://scripts/screens/title.gd"),
	"create": preload("res://scripts/screens/create.gd"),
	"world": preload("res://scripts/screens/world.gd"),
	"battle": preload("res://scripts/screens/battle.gd"),
	"ending": preload("res://scripts/screens/ending.gd"),
}

var current: Node = null


func _ready() -> void:
	change_screen("title")


func change_screen(screen: String, args := {}) -> void:
	get_viewport().set_input_as_handled()
	if current:
		current.queue_free()
	current = SCREENS[screen].new()
	current.set("main", self)
	current.set("args", args)
	add_child(current)


func _process(delta: float) -> void:
	if current and current.get("counts_playtime") == true:
		Game.playtime += delta
