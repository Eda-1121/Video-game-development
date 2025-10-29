# ui_manager.gd - UI管理器（左上角布局版）
extends CanvasLayer

# UI元素引用
var info_panel: Panel  # 统一的信息面板
var level_label: Label
var trump_label: Label

var team1_score_label: Label
var team2_score_label: Label

var turn_label: Label

var play_button: Button
var pass_button: Button

var center_message: Label

# 玩家头像框
var player_avatars: Array[Panel] = []
var player_name_labels: Array[Label] = []

# 信号
signal play_cards_pressed
signal pass_pressed

func _ready():
	layer = 1
	create_ui()

func create_ui():
	# =====================================
	# 左上角统一信息面板
	# =====================================
	info_panel = Panel.new()
	info_panel.position = Vector2(10, 10)
	info_panel.size = Vector2(300, 220)  # 增大以容纳所有信息
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_panel)
	
	# 创建一个VBoxContainer来垂直排列所有信息
	var info_container = VBoxContainer.new()
	info_container.position = Vector2(15, 10)
	info_container.add_theme_constant_override("separation", 5)
	info_panel.add_child(info_container)
	
	# 当前级别
	level_label = Label.new()
	level_label.text = "当前级别: 2"
	level_label.add_theme_font_size_override("font_size", 22)
	info_container.add_child(level_label)
	
	# 主花色
	trump_label = Label.new()
	trump_label.text = "主花色: ♠"
	trump_label.add_theme_font_size_override("font_size", 22)
	info_container.add_child(trump_label)
	
	# 分割线
	var separator1 = HSeparator.new()
	separator1.custom_minimum_size = Vector2(270, 2)
	info_container.add_child(separator1)
	
	# 队伍1标题和分数
	var team1_container = VBoxContainer.new()
	team1_container.add_theme_constant_override("separation", 2)
	info_container.add_child(team1_container)
	
	var team1_title = Label.new()
	team1_title.text = "队伍1"
	team1_title.add_theme_font_size_override("font_size", 20)
	team1_title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))  # 绿色
	team1_container.add_child(team1_title)
	
	team1_score_label = Label.new()
	team1_score_label.text = "得分: 0"
	team1_score_label.add_theme_font_size_override("font_size", 24)
	team1_container.add_child(team1_score_label)
	
	# 分割线
	var separator2 = HSeparator.new()
	separator2.custom_minimum_size = Vector2(270, 2)
	info_container.add_child(separator2)
	
	# 队伍2标题和分数
	var team2_container = VBoxContainer.new()
	team2_container.add_theme_constant_override("separation", 2)
	info_container.add_child(team2_container)
	
	var team2_title = Label.new()
	team2_title.text = "队伍2"
	team2_title.add_theme_font_size_override("font_size", 20)
	team2_title.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))  # 红色
	team2_container.add_child(team2_title)
	
	team2_score_label = Label.new()
	team2_score_label.text = "得分: 0"
	team2_score_label.add_theme_font_size_override("font_size", 24)
	team2_container.add_child(team2_score_label)
	
	# =====================================
	# 回合提示标签（移到顶部中央）
	# =====================================
	turn_label = Label.new()
	turn_label.position = Vector2(400, 10)
	turn_label.size = Vector2(480, 40)
	turn_label.text = "轮到你出牌"
	turn_label.add_theme_font_size_override("font_size", 22)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(turn_label)
	
	# =====================================
	# 底部按钮区
	# =====================================
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(480, 650)
	button_container.add_theme_constant_override("separation", 20)
	add_child(button_container)
	
	# 出牌按钮
	play_button = Button.new()
	play_button.text = "出牌"
	play_button.custom_minimum_size = Vector2(120, 50)
	play_button.add_theme_font_size_override("font_size", 24)
	play_button.pressed.connect(_on_play_button_pressed)
	button_container.add_child(play_button)
	
	# 过牌按钮
	pass_button = Button.new()
	pass_button.text = "过牌"
	pass_button.custom_minimum_size = Vector2(120, 50)
	pass_button.add_theme_font_size_override("font_size", 24)
	pass_button.pressed.connect(_on_pass_button_pressed)
	button_container.add_child(pass_button)
	
	# =====================================
	# 中央消息标签
	# =====================================
	center_message = Label.new()
	center_message.position = Vector2(340, 350)
	center_message.size = Vector2(600, 80)
	center_message.text = ""
	center_message.add_theme_font_size_override("font_size", 32)
	center_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_message.visible = false
	add_child(center_message)
	
	# =====================================
	# 玩家头像框（简化版，只在屏幕边缘显示）
	# =====================================
	create_player_avatars()
	
	print("UI创建完成（左上角布局）")

func create_player_avatars():
	"""创建4个玩家的头像框"""
	var avatar_positions = [
		Vector2(540, 620),  # 玩家1（下方）
		Vector2(10, 240),   # 玩家2（左侧，在信息面板下方）
		Vector2(540, 60),   # 玩家3（上方）
		Vector2(1150, 320)  # 玩家4（右侧）
	]
	
	var player_names = ["玩家1", "玩家2", "玩家3", "玩家4"]
	
	for i in range(4):
		# 创建头像面板
		var avatar_panel = Panel.new()
		avatar_panel.position = avatar_positions[i]
		avatar_panel.size = Vector2(120, 80)
		avatar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(avatar_panel)
		player_avatars.append(avatar_panel)
		
		# 玩家名称
		var name_label = Label.new()
		name_label.position = Vector2(10, 10)
		name_label.size = Vector2(100, 30)
		name_label.text = player_names[i]
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_panel.add_child(name_label)
		player_name_labels.append(name_label)
		
		# 状态标签
		var status_label = Label.new()
		status_label.position = Vector2(10, 45)
		status_label.size = Vector2(100, 25)
		status_label.text = ""
		status_label.add_theme_font_size_override("font_size", 16)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_panel.add_child(status_label)

# =====================================
# 按钮回调
# =====================================

func _on_play_button_pressed():
	print("点击了出牌按钮")
	play_cards_pressed.emit()

func _on_pass_button_pressed():
	print("点击了过牌按钮")
	pass_pressed.emit()

# =====================================
# 更新UI的方法
# =====================================

func update_level(level: int):
	level_label.text = "当前级别: %d" % level

func update_trump_suit(suit_symbol: String):
	trump_label.text = "主花色: %s" % suit_symbol

func update_team_scores(team1_score: int, team2_score: int):
	team1_score_label.text = "得分: %d" % team1_score
	team2_score_label.text = "得分: %d" % team2_score

func update_turn_message(message: String):
	turn_label.text = message

func show_center_message(message: String, duration: float = 2.0):
	"""显示中央临时消息"""
	center_message.text = message
	center_message.visible = true
	
	await get_tree().create_timer(duration).timeout
	center_message.visible = false

func set_buttons_enabled(enabled: bool):
	"""启用/禁用按钮"""
	play_button.disabled = not enabled
	pass_button.disabled = not enabled

func highlight_current_player(player_id: int):
	"""高亮当前出牌的玩家"""
	for i in range(player_avatars.size()):
		if i == player_id:
			player_avatars[i].modulate = Color(1.2, 1.2, 1.0)  # 高亮
		else:
			player_avatars[i].modulate = Color.WHITE
