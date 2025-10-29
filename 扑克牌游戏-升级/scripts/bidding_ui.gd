# bidding_ui.gd - 叫牌界面组件
extends Control
class_name BiddingUI

signal bid_made(suit: Card.Suit, count: int)
signal bid_passed

var bid_panel: Panel
var bid_buttons: Array[Button] = []
var pass_button: Button
var current_bid_label: Label

var suit_names = ["黑桃 ♠", "红心 ♥", "梅花 ♣", "方片 ♦", "无主 👑"]

func _ready():
	create_bidding_panel()
	visible = false

func create_bidding_panel():
	"""创建叫牌面板"""
	# 主面板
	bid_panel = Panel.new()
	bid_panel.position = Vector2(400, 250)
	bid_panel.size = Vector2(480, 220)
	add_child(bid_panel)
	
	# 标题
	var title_label = Label.new()
	title_label.position = Vector2(20, 10)
	title_label.size = Vector2(440, 30)
	title_label.text = "叫牌阶段 - 选择主花色"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid_panel.add_child(title_label)
	
	# 当前叫牌信息
	current_bid_label = Label.new()
	current_bid_label.position = Vector2(20, 50)
	current_bid_label.size = Vector2(440, 25)
	current_bid_label.text = "当前无人叫牌"
	current_bid_label.add_theme_font_size_override("font_size", 18)
	current_bid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid_panel.add_child(current_bid_label)
	
	# 花色按钮容器
	var button_container = GridContainer.new()
	button_container.position = Vector2(40, 90)
	button_container.size = Vector2(400, 80)
	button_container.columns = 3
	button_container.add_theme_constant_override("h_separation", 10)
	button_container.add_theme_constant_override("v_separation", 10)
	bid_panel.add_child(button_container)
	
	# 创建5个花色按钮（4个花色 + 无主）
	for i in range(5):
		var btn = Button.new()
		btn.text = suit_names[i]
		btn.custom_minimum_size = Vector2(120, 35)
		btn.add_theme_font_size_override("font_size", 18)
		
		# 连接信号，使用闭包捕获索引
		var suit_index = i
		btn.pressed.connect(func(): _on_suit_button_pressed(suit_index))
		
		button_container.add_child(btn)
		bid_buttons.append(btn)
	
	# 过牌按钮
	pass_button = Button.new()
	pass_button.position = Vector2(170, 180)
	pass_button.size = Vector2(140, 35)
	pass_button.text = "不叫"
	pass_button.add_theme_font_size_override("font_size", 20)
	pass_button.pressed.connect(_on_pass_button_pressed)
	bid_panel.add_child(pass_button)

func show_bidding_ui(can_bid: bool = true):
	"""显示叫牌界面"""
	visible = true
	
	# 根据是否可以叫牌来设置按钮状态
	for btn in bid_buttons:
		btn.disabled = not can_bid
	pass_button.disabled = false

func hide_bidding_ui():
	"""隐藏叫牌界面"""
	visible = false

func update_current_bid(message: String):
	"""更新当前叫牌信息"""
	current_bid_label.text = message

func _on_suit_button_pressed(suit_index: int):
	"""花色按钮被点击"""
	var suit: Card.Suit
	match suit_index:
		0: suit = Card.Suit.SPADE
		1: suit = Card.Suit.HEART
		2: suit = Card.Suit.CLUB
		3: suit = Card.Suit.DIAMOND
		4: suit = Card.Suit.JOKER  # 无主
		_: suit = Card.Suit.SPADE
	
	print("玩家选择叫: %s" % suit_names[suit_index])
	bid_made.emit(suit, 1)  # 暂时都是1张叫牌

func _on_pass_button_pressed():
	"""过牌按钮被点击"""
	print("玩家选择不叫")
	bid_passed.emit()

func enable_buttons(enabled: bool):
	"""启用/禁用所有按钮"""
	for btn in bid_buttons:
		btn.disabled = not enabled
	pass_button.disabled = not enabled
