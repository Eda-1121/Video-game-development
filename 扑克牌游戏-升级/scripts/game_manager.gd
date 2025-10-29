# game_manager.gd - 改进版游戏管理器
extends Node

enum GamePhase { BIDDING, BURYING, PLAYING, SCORING }

var deck: Deck
var players: Array[Player] = []
var current_phase: GamePhase = GamePhase.BIDDING

var trump_suit: Card.Suit = Card.Suit.SPADE
var current_level: int = 2
var dealer_index: int = 0
var current_player_index: int = 0

var bottom_cards: Array[Card] = []
var current_trick: Array = []
var team_scores: Array[int] = [0, 0]
var team_levels: Array[int] = [2, 2]  # 每队的级别

# 叫牌相关
var bidding_trump_suit: Card.Suit = Card.Suit.SPADE
var bidding_rank: int = 2
var bidding_team: int = -1  # 哪个队叫到主
var has_bid: bool = false

# 出牌区域
var play_area_positions = [
	Vector2(640, 480),  # 玩家1（下方）
	Vector2(320, 360),  # 玩家2（左侧）
	Vector2(640, 240),  # 玩家3（上方）
	Vector2(960, 360)   # 玩家4（右侧）
]

# UI管理器引用
var ui_manager = null

signal phase_changed(phase: GamePhase)

func _ready():
	print("=== GameManager 初始化 ===")
	initialize_game()

func initialize_game():
	# 创建牌堆
	deck = Deck.new(2)
	deck.create_deck()
	
	# 创建4个玩家
	var player_positions = [
		Vector2(100, 550),   # 下方（人类玩家）
		Vector2(-500, 360),  # 左侧 - 移到屏幕外
		Vector2(-500, 150),  # 上方 - 移到屏幕外
		Vector2(-500, 360)   # 右侧 - 移到屏幕外
	]
	
	for i in 4:
		var player = Player.new()
		player.player_id = i
		player.player_name = "玩家%d" % [i + 1]
		player.team = i % 2
		player.player_type = Player.PlayerType.AI if i > 0 else Player.PlayerType.HUMAN
		player.position = player_positions[i]
		players.append(player)
		add_child(player)
		print("创建 %s，位置: %v" % [player.player_name, player.position])
	
	start_new_round()

func start_new_round():
	print("=== 开始新一局 ===")
	
	# 重置状态
	team_scores = [0, 0]
	has_bid = false
	bidding_team = -1
	current_phase = GamePhase.BIDDING
	
	# 洗牌
	deck.shuffle()
	
	# 发牌
	bottom_cards = deck.deal_to_players(players)
	print("底牌: %d 张" % bottom_cards.size())
	
	print("发牌完成")
	for i in range(players.size()):
		print("   %s: %d 张牌" % [players[i].player_name, players[i].get_hand_size()])
	
	# 设置庄家
	players[dealer_index].is_dealer = true
	
	await get_tree().process_frame
	
	# 只显示玩家1的手牌
	print("显示玩家1的手牌...")
	players[0].show_cards(true)
	
	for i in range(1, 4):
		players[i].show_cards(false)
	
	print("=== 进入叫牌阶段 ===")
	
	# 更新UI
	if ui_manager:
		ui_manager.update_level(current_level)
		ui_manager.update_trump_suit("?")  # 叫牌阶段主花色未定
		ui_manager.update_team_scores(0, 0)
		ui_manager.update_turn_message("叫牌阶段 - 请翻出当前级别的牌叫主")
	
	phase_changed.emit(current_phase)
	
	# 开始叫牌流程
	start_bidding_phase()

func start_bidding_phase():
	"""开始叫牌阶段"""
	print("开始叫牌...")
	
	# TODO: 完整的叫牌逻辑
	# 这里简化处理：默认庄家队伍叫黑桃为主
	await get_tree().create_timer(2.0).timeout
	
	trump_suit = Card.Suit.SPADE
	bidding_team = players[dealer_index].team
	has_bid = true
	
	print("叫牌完成: %s 队叫到 %s 为主" % [get_team_name(bidding_team), get_trump_symbol()])
	
	if ui_manager:
		ui_manager.update_trump_suit(get_trump_symbol())
		ui_manager.show_center_message("%s队叫到主: %s" % [get_team_name(bidding_team), get_trump_symbol()], 2.0)
	
	# 等待消息显示
	await get_tree().create_timer(2.0).timeout
	
	# 进入埋底阶段
	if players[dealer_index].player_type == Player.PlayerType.HUMAN:
		start_burying_phase()
	else:
		# AI庄家自动埋底
		ai_bury_bottom()

func start_burying_phase():
	"""开始埋底阶段（庄家替换底牌）"""
	current_phase = GamePhase.BURYING
	print("=== 埋底阶段 ===")
	
	var dealer = players[dealer_index]
	
	# 给庄家底牌
	dealer.receive_cards(bottom_cards)
	bottom_cards.clear()
	
	if ui_manager:
		ui_manager.update_turn_message("庄家埋底 - 请选择8张牌作为底牌")
		ui_manager.show_center_message("庄家请选择8张牌扣底", 2.0)
	
	# TODO: 等待玩家选择8张牌埋底
	# 这里简化处理：自动选择最小的8张
	await get_tree().create_timer(3.0).timeout
	auto_bury_for_player(dealer)

func auto_bury_for_player(dealer: Player):
	"""自动为玩家埋底（选择最小的8张）"""
	# 排序手牌
	var sorted_hand = dealer.hand.duplicate()
	sorted_hand.sort_custom(func(a, b): 
		a.set_trump(trump_suit, current_level)
		b.set_trump(trump_suit, current_level)
		return a.compare_to(b, trump_suit, current_level) < 0
	)
	
	# 选择最小的8张作为底牌
	for i in range(min(8, sorted_hand.size())):
		bottom_cards.append(sorted_hand[i])
		dealer.hand.erase(sorted_hand[i])
	
	dealer.update_hand_display()
	
	print("埋底完成，底牌: %d 张" % bottom_cards.size())
	
	if ui_manager:
		ui_manager.show_center_message("埋底完成", 1.5)
	
	await get_tree().create_timer(1.5).timeout
	start_playing_phase()

func ai_bury_bottom():
	"""AI庄家埋底"""
	var dealer = players[dealer_index]
	
	# 给庄家底牌
	dealer.receive_cards(bottom_cards)
	bottom_cards.clear()
	
	await get_tree().create_timer(1.5).timeout
	
	# 简单AI：选择最小的8张
	auto_bury_for_player(dealer)

func start_playing_phase():
	"""开始出牌阶段"""
	current_phase = GamePhase.PLAYING
	print("=== 开始出牌阶段 ===")
	
	# 庄家先出
	current_player_index = dealer_index
	
	if ui_manager:
		ui_manager.update_turn_message("轮到 %s 出牌" % players[current_player_index].player_name)
		ui_manager.highlight_current_player(current_player_index)
	
	phase_changed.emit(current_phase)
	
	# 如果是AI先出
	if players[current_player_index].player_type == Player.PlayerType.AI:
		await get_tree().create_timer(1.0).timeout
		ai_play_turn(players[current_player_index])

func get_trump_symbol() -> String:
	"""获取主花色符号"""
	match trump_suit:
		Card.Suit.SPADE: return "♠"
		Card.Suit.HEART: return "♥"
		Card.Suit.CLUB: return "♣"
		Card.Suit.DIAMOND: return "♦"
		_: return "?"

func get_team_name(team: int) -> String:
	"""获取队伍名称"""
	return "队伍%d" % [team + 1]

func get_current_player() -> Player:
	return players[current_player_index]

# =====================================
# 按钮事件处理
# =====================================

func _on_play_cards_pressed():
	"""出牌按钮被点击"""
	if current_phase != GamePhase.PLAYING:
		return
	
	print("处理出牌...")
	
	var human_player = players[0]
	if human_player.selected_cards.is_empty():
		if ui_manager:
			ui_manager.show_center_message("请先选择要出的牌！", 1.5)
		print("没有选中任何牌")
		return
	
	# 更新主牌状态
	for card in human_player.selected_cards:
		card.set_trump(trump_suit, current_level)
	
	# 识别牌型
	var pattern = GameRules.identify_pattern(human_player.selected_cards, trump_suit, current_level)
	print("识别到牌型: %s，共 %d 张牌" % [get_pattern_name(pattern.pattern_type), pattern.cards.size()])
	
	# 验证是否可以出这些牌
	if not GameRules.validate_play(human_player.selected_cards, human_player.hand):
		if ui_manager:
			ui_manager.show_center_message("无效的出牌！", 1.5)
		return
	
	# 如果是首家出牌
	if current_trick.is_empty():
		if human_player.play_selected_cards():
			show_played_cards(0, pattern.cards)
			
			current_trick.append({
				"player_id": human_player.player_id,
				"cards": pattern.cards,
				"pattern": pattern
			})
			
			if ui_manager:
				ui_manager.show_center_message("出牌成功！", 1.0)
			print("首家出牌成功")
			
			next_player_turn()
		else:
			if ui_manager:
				ui_manager.show_center_message("出牌失败！", 1.5)
	else:
		# 跟牌逻辑
		var lead_pattern = current_trick[0]["pattern"]
		
		# 检查牌型是否匹配
		if not GameRules.can_follow(pattern, lead_pattern, human_player.hand, trump_suit, current_level):
			if ui_manager:
				ui_manager.show_center_message("跟牌不符合规则！", 1.5)
			print("跟牌不合法")
			return
		
		# 出牌
		if human_player.play_selected_cards():
			show_played_cards(0, pattern.cards)
			
			current_trick.append({
				"player_id": human_player.player_id,
				"cards": pattern.cards,
				"pattern": pattern
			})
			
			if ui_manager:
				ui_manager.show_center_message("跟牌成功！", 1.0)
			
			# 检查是否所有人都出牌了
			if current_trick.size() == 4:
				evaluate_trick()
			else:
				next_player_turn()

func show_played_cards(player_id: int, cards: Array):
	"""在桌面中央显示玩家出的牌"""
	var position = play_area_positions[player_id]
	
	for i in range(cards.size()):
		var card = cards[i]
		if not card.get_parent():
			add_child(card)
		
		card.position = position + Vector2(i * 20, 0)
		card.z_index = 100
		card.visible = true
		card.set_face_up(true, true)

func next_player_turn():
	"""轮到下一个玩家"""
	current_player_index = (current_player_index + 1) % 4
	var current_player = players[current_player_index]
	
	if ui_manager:
		ui_manager.update_turn_message("轮到 %s 出牌" % current_player.player_name)
		ui_manager.highlight_current_player(current_player_index)
	
	if current_player.player_type == Player.PlayerType.AI:
		await get_tree().create_timer(1.5).timeout
		ai_play_turn(current_player)

func ai_play_turn(ai_player: Player):
	"""AI出牌 - 改进版"""
	print("AI %s 出牌..." % ai_player.player_name)
	
	# 更新AI手牌的主牌状态
	for card in ai_player.hand:
		card.set_trump(trump_suit, current_level)
	
	var cards_to_play: Array = []
	
	if current_trick.is_empty():
		# 首家出牌：出最大的单张
		if ai_player.hand.size() > 0:
			var sorted_hand = ai_player.hand.duplicate()
			sorted_hand.sort_custom(func(a, b): 
				return a.compare_to(b, trump_suit, current_level) > 0
			)
			cards_to_play = [sorted_hand[0]]
	else:
		# 跟牌
		var lead_pattern = current_trick[0]["pattern"]
		var valid_plays = GameRules.get_valid_follow_cards(ai_player.hand, lead_pattern, trump_suit, current_level)
		
		if valid_plays.size() > 0:
			# 选择第一个合法出牌（可以优化为选择最优出牌）
			cards_to_play = valid_plays[0]
		elif ai_player.hand.size() >= lead_pattern.length:
			cards_to_play = ai_player.hand.slice(0, lead_pattern.length)
	
	# 出牌
	if cards_to_play.size() > 0:
		for card in cards_to_play:
			ai_player.hand.erase(card)
			if card.get_parent() == ai_player.hand_container:
				ai_player.hand_container.remove_child(card)
		
		ai_player.update_hand_display()
		
		# 转换为 Array[Card]
		var cards_array: Array[Card] = []
		for card in cards_to_play:
			cards_array.append(card)
		
		show_played_cards(ai_player.player_id, cards_array)
		
		var pattern = GameRules.identify_pattern(cards_array, trump_suit, current_level)
		current_trick.append({
			"player_id": ai_player.player_id,
			"cards": cards_array,
			"pattern": pattern
		})
		
		print("AI出牌: %d 张" % cards_to_play.size())
		
		if current_trick.size() == 4:
			await get_tree().create_timer(1.0).timeout
			evaluate_trick()
		else:
			next_player_turn()

func evaluate_trick():
	"""评估本轮出牌"""
	print("=== 评估本轮 ===")
	
	var lead_play = current_trick[0]
	var winner_play = lead_play
	
	# 找出最大的出牌
	for i in range(1, current_trick.size()):
		var current_play = current_trick[i]
		var compare_result = GameRules.compare_plays(winner_play["pattern"], current_play["pattern"], trump_suit, current_level)
		
		if compare_result < 0:
			winner_play = current_play
	
	var winner = players[winner_play["player_id"]]
	print("本轮胜者: %s" % winner.player_name)
	
	# 计算分数
	var points = 0
	for play in current_trick:
		points += GameRules.calculate_points(play["cards"])
	
	print("本轮得分: %d" % points)
	
	# 添加到队伍分数
	team_scores[winner.team] += points
	
	# 更新UI
	if ui_manager:
		ui_manager.update_team_scores(team_scores[0], team_scores[1])
		ui_manager.show_center_message("%s 赢得本轮，得 %d 分" % [winner.player_name, points], 2.0)
	
	await get_tree().create_timer(2.0).timeout
	
	# 清空桌面上的牌
	for play in current_trick:
		for card in play["cards"]:
			if is_instance_valid(card) and card.get_parent():
				card.queue_free()
	
	current_trick.clear()
	
	# 检查是否打完所有牌
	if players[0].get_hand_size() == 0:
		await get_tree().create_timer(1.0).timeout
		# 最后一轮，如果庄家队赢，底牌加倍分数给庄家队
		var bottom_points = GameRules.calculate_points(bottom_cards)
		var multiplier = 2  # 扣底倍数，可以根据最后一轮牌型调整
		
		if winner.team == bidding_team:
			team_scores[bidding_team] += bottom_points * multiplier
			print("庄家队拿底牌，加 %d 分" % [bottom_points * multiplier])
			if ui_manager:
				ui_manager.show_center_message("庄家队扣底成功！+%d分" % [bottom_points * multiplier], 2.0)
				ui_manager.update_team_scores(team_scores[0], team_scores[1])
		else:
			var opponent_team = 1 - bidding_team
			team_scores[opponent_team] += bottom_points * multiplier
			print("对手队抠底成功，加 %d 分" % [bottom_points * multiplier])
			if ui_manager:
				ui_manager.show_center_message("对手队抠底成功！+%d分" % [bottom_points * multiplier], 2.0)
				ui_manager.update_team_scores(team_scores[0], team_scores[1])
		
		await get_tree().create_timer(2.0).timeout
		end_round()
	else:
		# 赢家先出下一轮
		current_player_index = winner_play["player_id"]
		await get_tree().create_timer(1.0).timeout
		
		if ui_manager:
			ui_manager.update_turn_message("轮到 %s 出牌" % players[current_player_index].player_name)
			ui_manager.highlight_current_player(current_player_index)
		
		if players[current_player_index].player_type == Player.PlayerType.AI:
			await get_tree().create_timer(1.0).timeout
			ai_play_turn(players[current_player_index])

func end_round():
	"""本局结束，计算升级"""
	current_phase = GamePhase.SCORING
	print("=== 本局结束 ===")
	print("队伍1得分: %d" % team_scores[0])
	print("队伍2得分: %d" % team_scores[1])
	
	# 计算升级
	var attacker_team = 1 - bidding_team
	var attacker_score = team_scores[attacker_team]
	
	var levels_to_advance = 0
	
	# 升级规则（简化版）
	if attacker_score >= 120:
		# 对手得分超过120，升级
		if attacker_score >= 160:
			levels_to_advance = 3
		elif attacker_score >= 140:
			levels_to_advance = 2
		else:
			levels_to_advance = 1
		
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4  # 轮换庄家
		
		print("对手队升级 %d 级！" % levels_to_advance)
		if ui_manager:
			ui_manager.show_center_message("队伍%d 获胜！升%d级！" % [attacker_team + 1, levels_to_advance], 3.0)
	else:
		# 庄家队守住，可能升级
		if attacker_score < 80:
			levels_to_advance = 2
		elif attacker_score < 40:
			levels_to_advance = 3
		else:
			levels_to_advance = 0
		
		if levels_to_advance > 0:
			team_levels[bidding_team] += levels_to_advance
			print("庄家队升级 %d 级！" % levels_to_advance)
			if ui_manager:
				ui_manager.show_center_message("队伍%d 守住！升%d级！" % [bidding_team + 1, levels_to_advance], 3.0)
		else:
			print("庄家队守住，不升级")
			if ui_manager:
				ui_manager.show_center_message("队伍%d 守住！" % [bidding_team + 1], 3.0)
		# 庄家不变
	
	# 更新当前级别（取最大值，实际应该分队跟踪）
	current_level = max(team_levels[0], team_levels[1])
	
	print("队伍1级别: %d，队伍2级别: %d" % [team_levels[0], team_levels[1]])
	
	# TODO: 检查是否有队伍打到A，游戏结束

func get_pattern_name(pattern_type: GameRules.CardPattern) -> String:
	"""获取牌型名称"""
	match pattern_type:
		GameRules.CardPattern.SINGLE: return "单张"
		GameRules.CardPattern.PAIR: return "对子"
		GameRules.CardPattern.TRACTOR: return "拖拉机"
		GameRules.CardPattern.THROW: return "甩牌"
		_: return "无效"

func _on_pass_pressed():
	"""过牌按钮"""
	print("玩家选择过牌")
	if ui_manager:
		ui_manager.show_center_message("过牌", 1.0)
