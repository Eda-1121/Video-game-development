# game_manager.gd - Phase 2 完整版游戏管理器
extends Node

enum GamePhase { DEALING_AND_BIDDING, BURYING, PLAYING, SCORING }

var deck: Deck
var players: Array[Player] = []
var current_phase: GamePhase = GamePhase.DEALING_AND_BIDDING

var trump_suit: Card.Suit = Card.Suit.SPADE
var current_level: int = 2
var dealer_index: int = 0
var current_player_index: int = 0

var bottom_cards: Array[Card] = []
var current_trick: Array = []
var team_scores: Array[int] = [0, 0]
var team_levels: Array[int] = [2, 2]

# 叫牌相关
var current_bid = {
	"team": -1,
	"suit": Card.Suit.SPADE,
	"count": 0,  # 叫牌张数(1=单张, 2=对子)
	"player_id": -1
}
var bidding_round: int = 0
var max_bidding_rounds: int = 8  # 每人最多叫2次

# 游戏统计
var total_rounds_played: int = 0

# 出牌区域
var play_area_positions = [
	Vector2(640, 480),
	Vector2(320, 360),
	Vector2(640, 240),
	Vector2(960, 360)
]

# UI管理器引用
var ui_manager = null

signal phase_changed(phase: GamePhase)
signal game_over(winner_team: int)

func _ready():
	print("=== GameManager 初始化 (Phase 2) ===")
	initialize_game()

func initialize_game():
	deck = Deck.new(2)
	deck.create_deck()

	# 玩家位置：玩家1在下方，玩家2在左侧，玩家3在上方，玩家4在右侧
	var player_positions = [
		Vector2(100, 550),   # 玩家1（人类）- 下方
		Vector2(50, 280),    # 玩家2（AI）- 左侧
		Vector2(100, 50),    # 玩家3（AI）- 上方
		Vector2(1050, 280)   # 玩家4（AI）- 右侧
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
	
	start_new_round()

func start_new_round():
	print("=== 开始新一局 ===")
	total_rounds_played += 1
	
	team_scores = [0, 0]
	current_bid = {
		"team": -1,
		"suit": Card.Suit.SPADE,
		"count": 0,
		"player_id": -1
	}
	bidding_round = 0
	current_phase = GamePhase.DEALING_AND_BIDDING

	deck.shuffle()

	# 留出底牌
	for _i in 8:
		if deck.cards.size() > 0:
			bottom_cards.append(deck.cards.pop_back())

	players[dealer_index].is_dealer = true

	# 初始化UI
	if ui_manager:
		ui_manager.update_level(current_level)
		ui_manager.update_trump_suit("?")
		ui_manager.update_team_scores(0, 0)
		ui_manager.update_turn_message("正在发牌...")

		# 显示叫牌UI（但按钮禁用）
		if ui_manager.has_node("BiddingUI"):
			var bidding_ui = ui_manager.get_node("BiddingUI")
			bidding_ui.show_bidding_ui(false)
			bidding_ui.update_current_bid("当前无人叫牌")

	phase_changed.emit(current_phase)

	# 等待一帧后开始逐张发牌
	await get_tree().process_frame
	start_dealing_cards()

# =====================================
# 发牌系统
# =====================================

func start_dealing_cards():
	"""开始逐张发牌"""
	# 确保所有玩家可见
	for i in range(4):
		players[i].visible = true

	var total_cards = deck.cards.size()
	var card_index = 0
	var current_player = dealer_index

	# 逐张发牌
	while deck.cards.size() > 0:
		var card = deck.cards.pop_back()
		var player = players[current_player]

		# 将牌发给玩家
		player.receive_cards([card])

		# 设置卡牌显示
		if player.player_type == Player.PlayerType.HUMAN:
			card.set_face_up(true, false)  # 人类玩家的牌正面朝上
		else:
			card.set_face_up(false, true)  # AI玩家的牌背面朝上

		card_index += 1

		# 更新UI显示发牌进度
		if ui_manager:
			ui_manager.update_turn_message("正在发牌... (%d/%d)" % [card_index, total_cards])

		# 检查该玩家是否可以叫牌
		await check_and_handle_bidding(player, card)

		# 下一个玩家
		current_player = (current_player + 1) % 4

		# 发牌延迟（让玩家看到发牌过程）
		await get_tree().create_timer(0.1).timeout

	# 发牌完成
	finish_dealing()

func check_and_handle_bidding(player: Player, latest_card: Card):
	"""检查玩家是否可以叫牌，并处理叫牌"""
	# 检查玩家手里是否有当前级别的牌
	var level_cards = []
	for card in player.hand:
		if card.rank == current_level:
			level_cards.append(card)

	if level_cards.is_empty():
		return

	# 计算可以叫的最大张数
	var suit_counts = {}
	for card in level_cards:
		if not suit_counts.has(card.suit):
			suit_counts[card.suit] = 0
		suit_counts[card.suit] += 1

	# 找到最多的花色及张数
	var max_count = 0
	var max_suit = null
	for suit in suit_counts:
		if suit_counts[suit] > max_count:
			max_count = suit_counts[suit]
			max_suit = suit

	# 如果是人类玩家且拿到了当前级别的牌
	if player.player_type == Player.PlayerType.HUMAN and max_count > 0:
		# 显示叫牌提示
		if can_make_bid(player, max_suit, max_count):
			if ui_manager and ui_manager.has_node("BiddingUI"):
				var bidding_ui = ui_manager.get_node("BiddingUI")
				bidding_ui.enable_buttons(true)
			# 等待玩家叫牌或选择不叫（使用超时机制）
			await get_tree().create_timer(1.0).timeout

	# AI玩家自动叫牌逻辑
	elif player.player_type == Player.PlayerType.AI:
		# 如果有对子且可以叫牌
		if max_count >= 2 and can_make_bid(player, max_suit, 2):
			make_bid(player, max_suit, 2)
		# 如果有单张且还没人叫
		elif max_count >= 1 and current_bid["count"] == 0:
			make_bid(player, max_suit, 1)

func finish_dealing():
	"""发牌完成，确定主牌"""
	if ui_manager:
		ui_manager.update_turn_message("发牌完成")

		# 隐藏叫牌UI
		if ui_manager.has_node("BiddingUI"):
			var bidding_ui = ui_manager.get_node("BiddingUI")
			bidding_ui.hide_bidding_ui()

	# 如果没人叫牌，默认庄家队叫黑桃
	if current_bid["count"] == 0:
		trump_suit = Card.Suit.SPADE
		current_bid["team"] = players[dealer_index].team
	else:
		trump_suit = current_bid["suit"]
		dealer_index = current_bid["player_id"]  # 叫到主的人成为庄家

	if ui_manager:
		ui_manager.update_trump_suit(get_trump_symbol())
		ui_manager.show_center_message("队伍%d 叫到主: %s" % [current_bid["team"] + 1, get_trump_symbol()], 2.0)

	await get_tree().create_timer(2.0).timeout

	# 进入埋底阶段
	if players[dealer_index].player_type == Player.PlayerType.HUMAN:
		start_burying_phase()
	else:
		ai_bury_bottom()

# =====================================
# 叫牌系统
# =====================================

func start_bidding_phase():
	"""开始叫牌阶段"""
	current_player_index = dealer_index
	process_bidding_turn()

func process_bidding_turn():
	"""处理当前玩家的叫牌轮次"""
	if bidding_round >= max_bidding_rounds:
		# 叫牌结束
		finish_bidding()
		return
	
	var current_player = players[current_player_index]
	
	if ui_manager:
		ui_manager.update_turn_message("%s 叫牌中..." % current_player.player_name)

	if current_player.player_type == Player.PlayerType.HUMAN:
		# 人类玩家，等待UI输入
		if ui_manager and ui_manager.has_node("BiddingUI"):
			var bidding_ui = ui_manager.get_node("BiddingUI")
			bidding_ui.enable_buttons(true)
	else:
		# AI玩家，自动叫牌
		await get_tree().create_timer(1.5).timeout
		ai_make_bid(current_player)

func _on_player_bid_made(suit: Card.Suit, count: int):
	"""玩家做出叫牌"""
	# 在发牌阶段，玩家1（人类）叫牌
	var player = players[0]

	# 验证叫牌是否有效
	if not can_make_bid(player, suit, count):
		if ui_manager:
			ui_manager.show_center_message("叫牌无效!", 1.5)
		return

	# 执行叫牌
	make_bid(player, suit, count)

	# 禁用叫牌按钮
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.enable_buttons(false)

func _on_player_bid_passed():
	"""玩家选择不叫"""
	# 禁用叫牌按钮
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.enable_buttons(false)

func can_make_bid(player: Player, suit: Card.Suit, count: int) -> bool:
	"""检查是否可以叫牌"""
	# 如果还没有人叫牌，任何人都可以叫
	if current_bid["count"] == 0:
		return true
	
	# 如果已经有人叫牌
	# 1. 同队加固：相同花色，更多张数
	if player.team == current_bid["team"]:
		if suit == current_bid["suit"] and count > current_bid["count"]:
			return true
	
	# 2. 反主：不同队，更多张数（任意花色）
	if player.team != current_bid["team"]:
		if count > current_bid["count"]:
			return true
	
	# 3. 无主特殊规则：小王=1张无主，大王=2张无主（最大）
	if suit == Card.Suit.JOKER:
		return true
	
	return false

func make_bid(player: Player, suit: Card.Suit, count: int):
	"""执行叫牌"""
	current_bid = {
		"team": player.team,
		"suit": suit,
		"count": count,
		"player_id": player.player_id
	}
	
	var suit_name = get_suit_name(suit)

	if ui_manager:
		var message = "%s 叫 %s" % [player.player_name, suit_name]
		ui_manager.show_center_message(message, 2.0)
		
		if ui_manager.has_node("BiddingUI"):
			var bidding_ui = ui_manager.get_node("BiddingUI")
			bidding_ui.update_current_bid("当前: %s - %s" % [player.player_name, suit_name])

func ai_make_bid(ai_player: Player):
	"""AI叫牌逻辑"""
	# 简化AI：检查手牌中当前级别的牌
	var level_cards = []
	for card in ai_player.hand:
		if card.rank == current_level:
			level_cards.append(card)
	
	# 如果有当前级别的对子，考虑叫牌或反主
	if level_cards.size() >= 2:
		var suit_counts = {}
		for card in level_cards:
			if not suit_counts.has(card.suit):
				suit_counts[card.suit] = 0
			suit_counts[card.suit] += 1
		
		# 找到对子
		for suit in suit_counts:
			if suit_counts[suit] >= 2:
				# 检查是否可以叫牌
				if can_make_bid(ai_player, suit, 2):
					make_bid(ai_player, suit, 2)
					next_bidding_turn()
					return
	
	# 如果有单张且还没人叫，就叫
	if level_cards.size() >= 1 and current_bid["count"] == 0:
		make_bid(ai_player, level_cards[0].suit, 1)
		next_bidding_turn()
		return
	
	# 否则不叫
	next_bidding_turn()

func next_bidding_turn():
	"""下一个叫牌轮次"""
	bidding_round += 1
	current_player_index = (current_player_index + 1) % 4
	
	# 禁用UI按钮
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.enable_buttons(false)
	
	await get_tree().create_timer(0.5).timeout
	process_bidding_turn()

func finish_bidding():
	"""结束叫牌阶段"""
	# 隐藏叫牌UI
	if ui_manager and ui_manager.has_node("BiddingUI"):
		var bidding_ui = ui_manager.get_node("BiddingUI")
		bidding_ui.hide_bidding_ui()
	
	# 如果没人叫牌，默认庄家队叫黑桃
	if current_bid["count"] == 0:
		trump_suit = Card.Suit.SPADE
		current_bid["team"] = players[dealer_index].team
	else:
		trump_suit = current_bid["suit"]
		dealer_index = current_bid["player_id"]  # 叫到主的人成为庄家
	
	if ui_manager:
		ui_manager.update_trump_suit(get_trump_symbol())
		ui_manager.show_center_message("队伍%d 叫到主: %s" % [current_bid["team"] + 1, get_trump_symbol()], 2.0)
	
	await get_tree().create_timer(2.0).timeout
	
	# 进入埋底阶段
	if players[dealer_index].player_type == Player.PlayerType.HUMAN:
		start_burying_phase()
	else:
		ai_bury_bottom()

func get_suit_name(suit: Card.Suit) -> String:
	"""获取花色名称"""
	match suit:
		Card.Suit.SPADE: return "黑桃♠"
		Card.Suit.HEART: return "红心♥"
		Card.Suit.CLUB: return "梅花♣"
		Card.Suit.DIAMOND: return "方片♦"
		Card.Suit.JOKER: return "无主👑"
		_: return "?"

# =====================================
# 埋底阶段
# =====================================

func start_burying_phase():
	"""开始埋底阶段"""
	current_phase = GamePhase.BURYING

	var dealer = players[dealer_index]
	
	dealer.receive_cards(bottom_cards)
	bottom_cards.clear()
	
	if ui_manager:
		ui_manager.update_turn_message("庄家埋底 - 请选择8张牌作为底牌")
		ui_manager.show_center_message("庄家请选择8张牌扣底", 2.0)
		ui_manager.show_bury_button(true)
		ui_manager.set_bury_button_enabled(false)

func _on_bury_cards_pressed():
	"""玩家点击埋底按钮"""
	if current_phase != GamePhase.BURYING:
		return
	
	var dealer = players[dealer_index]
	
	if dealer.selected_cards.size() != 8:
		if ui_manager:
			ui_manager.show_center_message("请选择正好8张牌!", 1.5)
		return

	for card in dealer.selected_cards:
		bottom_cards.append(card)
		dealer.hand.erase(card)
		if card.get_parent() == dealer.hand_container:
			dealer.hand_container.remove_child(card)
		card.set_selected(false)
	
	dealer.selected_cards.clear()
	dealer.update_hand_display()
	
	if ui_manager:
		ui_manager.show_bury_button(false)
		ui_manager.show_center_message("埋底完成", 1.5)

	await get_tree().create_timer(1.5).timeout
	start_playing_phase()

func auto_bury_for_player(dealer: Player):
	"""自动埋底"""
	var sorted_hand = dealer.hand.duplicate()
	sorted_hand.sort_custom(func(a, b): 
		a.set_trump(trump_suit, current_level)
		b.set_trump(trump_suit, current_level)
		return a.compare_to(b, trump_suit, current_level) < 0
	)
	
	for i in range(min(8, sorted_hand.size())):
		bottom_cards.append(sorted_hand[i])
		dealer.hand.erase(sorted_hand[i])
	
	dealer.update_hand_display()

	if ui_manager:
		ui_manager.show_center_message("埋底完成", 1.5)
	
	await get_tree().create_timer(1.5).timeout
	start_playing_phase()

func ai_bury_bottom():
	"""AI埋底"""
	var dealer = players[dealer_index]
	
	dealer.receive_cards(bottom_cards)
	bottom_cards.clear()
	
	await get_tree().create_timer(1.5).timeout
	auto_bury_for_player(dealer)

# =====================================
# 出牌阶段
# =====================================

func start_playing_phase():
	"""开始出牌阶段"""
	current_phase = GamePhase.PLAYING

	current_player_index = dealer_index
	
	if ui_manager:
		ui_manager.update_turn_message("轮到 %s 出牌" % players[current_player_index].player_name)
		ui_manager.highlight_current_player(current_player_index)
	
	phase_changed.emit(current_phase)
	
	if players[current_player_index].player_type == Player.PlayerType.AI:
		await get_tree().create_timer(1.0).timeout
		ai_play_turn(players[current_player_index])

func get_trump_symbol() -> String:
	match trump_suit:
		Card.Suit.SPADE: return "♠"
		Card.Suit.HEART: return "♥"
		Card.Suit.CLUB: return "♣"
		Card.Suit.DIAMOND: return "♦"
		Card.Suit.JOKER: return "👑"
		_: return "?"

func get_team_name(team: int) -> String:
	return "队伍%d" % [team + 1]

func get_current_player() -> Player:
	return players[current_player_index]

func _on_play_cards_pressed():
	"""出牌按钮被点击"""
	if current_phase != GamePhase.PLAYING:
		return

	var human_player = players[0]
	if human_player.selected_cards.is_empty():
		if ui_manager:
			ui_manager.show_center_message("请先选择要出的牌!", 1.5)
		return
	
	for card in human_player.selected_cards:
		card.set_trump(trump_suit, current_level)
	
	var pattern = GameRules.identify_pattern(human_player.selected_cards, trump_suit, current_level)

	if not GameRules.validate_play(human_player.selected_cards, human_player.hand):
		if ui_manager:
			ui_manager.show_center_message("无效的出牌!", 1.5)
		return
	
	if current_trick.is_empty():
		# 首家出牌
		if pattern.pattern_type == GameRules.CardPattern.THROW:
			# 甩牌需要验证
			if not validate_throw(human_player, pattern):
				if ui_manager:
					ui_manager.show_center_message("甩牌失败! 其他人能管上", 2.0)
				# 甩牌失败，只出最大的牌
				var largest_card = GameRules.get_largest_card(pattern.cards, trump_suit, current_level)
				human_player.selected_cards.clear()
				human_player.selected_cards.append(largest_card)
				pattern = GameRules.identify_pattern([largest_card], trump_suit, current_level)
		
		if human_player.play_selected_cards():
			show_played_cards(0, pattern.cards)
			
			current_trick.append({
				"player_id": human_player.player_id,
				"cards": pattern.cards,
				"pattern": pattern
			})


			if ui_manager:
				ui_manager.show_center_message("出牌成功!", 1.0)

			next_player_turn()
		else:
			if ui_manager:
				ui_manager.show_center_message("出牌失败!", 1.5)
	else:
		# 跟牌
		var lead_pattern = current_trick[0]["pattern"]
		
		if not GameRules.can_follow(pattern, lead_pattern, human_player.hand, trump_suit, current_level):
			if ui_manager:
				ui_manager.show_center_message("跟牌不符合规则!", 1.5)
			return
		
		if human_player.play_selected_cards():
			show_played_cards(0, pattern.cards)
			
			current_trick.append({
				"player_id": human_player.player_id,
				"cards": pattern.cards,
				"pattern": pattern
			})
			
			if ui_manager:
				ui_manager.show_center_message("跟牌成功!", 1.0)
			
			if current_trick.size() == 4:
				evaluate_trick()
			else:
				next_player_turn()

func validate_throw(player: Player, throw_pattern: GameRules.PlayPattern) -> bool:
	"""验证甩牌是否成功"""
	# 检查其他三家是否都管不上
	for i in range(1, 4):
		var other_player = players[(player.player_id + i) % 4]
		
		# 更新手牌主牌状态
		for card in other_player.hand:
			card.set_trump(trump_suit, current_level)
		
		# 检查是否能管上甩出的任何一张牌
		for throw_card in throw_pattern.cards:
			for hand_card in other_player.hand:
				if can_beat_card(hand_card, throw_card):
					return false

	return true

func can_beat_card(card1: Card, card2: Card) -> bool:
	"""检查card1是否能打过card2"""
	return card1.compare_to(card2, trump_suit, current_level) > 0

func show_played_cards(player_id: int, cards: Array):
	"""显示出的牌"""
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
	"""下一个玩家"""
	current_player_index = (current_player_index + 1) % 4
	var current_player = players[current_player_index]
	
	if ui_manager:
		ui_manager.update_turn_message("轮到 %s 出牌" % current_player.player_name)
		ui_manager.highlight_current_player(current_player_index)
	
	if current_player.player_type == Player.PlayerType.AI:
		await get_tree().create_timer(1.5).timeout
		ai_play_turn(current_player)

func ai_play_turn(ai_player: Player):
	"""AI出牌"""
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
			cards_to_play = valid_plays[0]
		elif ai_player.hand.size() >= lead_pattern.length:
			var sorted_hand = ai_player.hand.duplicate()
			sorted_hand.sort_custom(func(a, b): 
				return a.compare_to(b, trump_suit, current_level) < 0
			)
			cards_to_play = sorted_hand.slice(0, lead_pattern.length)
	
	if cards_to_play.size() > 0:
		for card in cards_to_play:
			ai_player.hand.erase(card)
			if card.get_parent() == ai_player.hand_container:
				ai_player.hand_container.remove_child(card)
		
		ai_player.update_hand_display()
		
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

		if current_trick.size() == 4:
			await get_tree().create_timer(1.0).timeout
			evaluate_trick()
		else:
			next_player_turn()

func evaluate_trick():
	"""评估本轮"""
	var lead_play = current_trick[0]
	var winner_play = lead_play
	
	for i in range(1, current_trick.size()):
		var current_play = current_trick[i]
		var compare_result = GameRules.compare_plays(winner_play["pattern"], current_play["pattern"], trump_suit, current_level)
		
		if compare_result < 0:
			winner_play = current_play

	var winner = players[winner_play["player_id"]]

	var points = 0
	for play in current_trick:
		points += GameRules.calculate_points(play["cards"])

	team_scores[winner.team] += points
	
	if ui_manager:
		ui_manager.update_team_scores(team_scores[0], team_scores[1])
		ui_manager.show_center_message("%s 赢得本轮，得 %d 分" % [winner.player_name, points], 2.0)
	
	await get_tree().create_timer(2.0).timeout
	
	for play in current_trick:
		for card in play["cards"]:
			if is_instance_valid(card) and card.get_parent():
				card.queue_free()
	
	current_trick.clear()
	
	if players[0].get_hand_size() == 0:
		await get_tree().create_timer(1.0).timeout
		
		var bottom_points = GameRules.calculate_points(bottom_cards)
		var multiplier = 2


		if winner.team == current_bid["team"]:
			team_scores[current_bid["team"]] += bottom_points * multiplier
			if ui_manager:
				ui_manager.show_center_message("庄家队扣底成功!+%d分" % [bottom_points * multiplier], 2.0)
				ui_manager.update_team_scores(team_scores[0], team_scores[1])
		else:
			var opponent_team = 1 - current_bid["team"]
			team_scores[opponent_team] += bottom_points * multiplier
			if ui_manager:
				ui_manager.show_center_message("对手队抠底成功!+%d分" % [bottom_points * multiplier], 2.0)
				ui_manager.update_team_scores(team_scores[0], team_scores[1])
		
		await get_tree().create_timer(2.0).timeout
		end_round()
	else:
		current_player_index = winner_play["player_id"]
		await get_tree().create_timer(1.0).timeout
		
		if ui_manager:
			ui_manager.update_turn_message("轮到 %s 出牌" % players[current_player_index].player_name)
			ui_manager.highlight_current_player(current_player_index)
		
		if players[current_player_index].player_type == Player.PlayerType.AI:
			await get_tree().create_timer(1.0).timeout
			ai_play_turn(players[current_player_index])

# =====================================
# 结束和升级
# =====================================

func end_round():
	"""本局结束"""
	current_phase = GamePhase.SCORING

	var attacker_team = 1 - current_bid["team"]
	var attacker_score = team_scores[attacker_team]
	
	var levels_to_advance = 0
	
	if attacker_score >= 120:
		if attacker_score >= 160:
			levels_to_advance = 3
		elif attacker_score >= 140:
			levels_to_advance = 2
		else:
			levels_to_advance = 1
		
		team_levels[attacker_team] += levels_to_advance
		dealer_index = (dealer_index + 1) % 4

		if ui_manager:
			ui_manager.show_center_message("队伍%d 获胜!升%d级!" % [attacker_team + 1, levels_to_advance], 3.0)
	else:
		if attacker_score < 80:
			levels_to_advance = 2
		elif attacker_score < 40:
			levels_to_advance = 3
		else:
			levels_to_advance = 0

		if levels_to_advance > 0:
			team_levels[current_bid["team"]] += levels_to_advance
			if ui_manager:
				ui_manager.show_center_message("队伍%d 守住!升%d级!" % [current_bid["team"] + 1, levels_to_advance], 3.0)
		else:
			if ui_manager:
				ui_manager.show_center_message("队伍%d 守住!" % [current_bid["team"] + 1], 3.0)

	current_level = max(team_levels[0], team_levels[1])
	
	await get_tree().create_timer(3.0).timeout
	
	# 检查游戏是否结束
	if check_game_over():
		show_game_over_screen()
	else:
		# 继续下一局
		start_new_round()

func check_game_over() -> bool:
	"""检查游戏是否结束"""
	# A = 14
	if team_levels[0] >= 14 or team_levels[1] >= 14:
		return true
	return false

func show_game_over_screen():
	"""显示游戏结束画面"""
	var winner_team = 0 if team_levels[0] >= 14 else 1
	
	if ui_manager and ui_manager.has_node("GameOverUI"):
		var game_over_ui = ui_manager.get_node("GameOverUI")
		game_over_ui.show_game_over(winner_team, team_levels[0], team_levels[1], total_rounds_played)
	
	game_over.emit(winner_team)

func restart_game():
	"""重新开始游戏"""
	# 重置所有状态
	team_levels = [2, 2]
	current_level = 2
	total_rounds_played = 0
	dealer_index = 0
	
	# 清理玩家手牌
	for player in players:
		for card in player.hand:
			if is_instance_valid(card):
				card.queue_free()
		player.hand.clear()
		player.selected_cards.clear()
	
	# 隐藏游戏结束界面
	if ui_manager and ui_manager.has_node("GameOverUI"):
		var game_over_ui = ui_manager.get_node("GameOverUI")
		game_over_ui.hide_game_over()
	
	# 开始新游戏
	start_new_round()

func get_pattern_name(pattern_type: GameRules.CardPattern) -> String:
	match pattern_type:
		GameRules.CardPattern.SINGLE: return "单张"
		GameRules.CardPattern.PAIR: return "对子"
		GameRules.CardPattern.TRACTOR: return "拖拉机"
		GameRules.CardPattern.THROW: return "甩牌"
		_: return "无效"

func _on_pass_pressed():
	"""过牌按钮"""
	if ui_manager:
		ui_manager.show_center_message("过牌", 1.0)
