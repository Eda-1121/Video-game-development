# main.gd - 主场景脚本
extends Node2D

var game_manager: Node
var ui_manager: CanvasLayer

func _ready():
	# 设置窗口
	get_window().title = "升级 - 拖拉机"
	get_window().size = Vector2i(1280, 720)
	
	# 添加全屏绿色背景
	var background = ColorRect.new()
	background.color = Color(0.05, 0.37, 0.14)  # 深绿色牌桌
	background.position = Vector2.ZERO
	background.size = Vector2(1280, 720)
	background.z_index = -10  # 确保在最底层
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让鼠标事件穿透！
	add_child(background)
	
	print("游戏启动成功！")
	print("窗口大小: ", get_window().size)
	
	# 创建UI管理器
	ui_manager = CanvasLayer.new()
	ui_manager.name = "UIManager"
	var ui_script = load("res://scripts/ui_manager.gd")
	ui_manager.set_script(ui_script)
	add_child(ui_manager)
	print("UIManager 已创建")
	
	# 创建游戏管理器
	game_manager = Node.new()
	game_manager.name = "GameManager"
	var game_script = load("res://scripts/game_manager.gd")
	game_manager.set_script(game_script)
	add_child(game_manager)
	print("GameManager 已创建")
	
	# 连接UI和游戏管理器
	ui_manager.play_cards_pressed.connect(game_manager._on_play_cards_pressed)
	ui_manager.pass_pressed.connect(game_manager._on_pass_pressed)
	game_manager.ui_manager = ui_manager

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("按ESC退出游戏")
			get_tree().quit()
