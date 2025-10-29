# player.gd - 玩家类(改进版)
extends Node2D
class_name Player

signal cards_played(cards: Array[Card])
signal card_selected(card: Card)
signal selection_changed(count: int)  # 新增:选牌数量变化信号

enum PlayerType { HUMAN, AI }

var player_id: int = 0
var player_name: String = "玩家"
var player_type: PlayerType = PlayerType.HUMAN
var team: int = 0
var current_rank: int = 2

var hand: Array[Card] = []
var is_dealer: bool = false

# UI相关
var hand_container: Node2D
var card_spacing: float = 35.0
var selected_cards: Array[Card] = []

func _ready():
	hand_container = Node2D.new()
	hand_container.name = "HandContainer"
	add_child(hand_container)

func receive_cards(cards: Array[Card]):
	for card in cards:
		hand.append(card)
		
		if card.get_parent():
			card.get_parent().remove_child(card)
		hand_container.add_child(card)
		
		card.visible = true
		
		# プレイヤー1（人間）の場合のみ表向きにする
		if player_type == PlayerType.HUMAN:
			card.set_face_up(true, true)  # ← この行を追加
		
		if not card.card_clicked.is_connected(_on_card_clicked):
			card.card_clicked.connect(_on_card_clicked)
	
	sort_hand()
	update_hand_display()

func sort_hand():
	hand.sort_custom(func(a, b): 
		if a.is_trump != b.is_trump:
			return a.is_trump
		if a.suit != b.suit:
			return a.suit < b.suit
		return a.rank < b.rank
	)

func update_hand_display(animate: bool = true):
	for i in range(hand.size()):
		var card = hand[i]
		var target_pos = Vector2(i * card_spacing, 0)
		
		if animate:
			card.move_to(target_pos, 0.3)
		else:
			card.position = target_pos
		
		card.z_index = i 

func _on_card_clicked(card: Card):
	if player_type != PlayerType.HUMAN:
		return
	
	if card.is_selected:
		card.set_selected(false)
		selected_cards.erase(card)
		# 元のz_indexに戻す
		card.z_index = hand.find(card)
	else:
		card.set_selected(true)
		selected_cards.append(card)
		# 選択されたカードを最前面に
		card.z_index = 1000 + selected_cards.size()
	
	# 発出選牌変化信号
	selection_changed.emit(selected_cards.size())
	card_selected.emit(card)

func play_selected_cards() -> bool:
	if selected_cards.is_empty():
		return false
	
	return play_cards(selected_cards)

func play_cards(cards: Array[Card]) -> bool:
	if not can_play_cards(cards):
		return false
	
	for card in cards:
		hand.erase(card)
		if card.get_parent() == hand_container:
			hand_container.remove_child(card)
	
	selected_cards.clear()
	
	update_hand_display()
	cards_played.emit(cards)
	return true

func can_play_cards(cards: Array[Card]) -> bool:
	for card in cards:
		if not hand.has(card):
			return false
	return true

func get_valid_plays(lead_cards: Array[Card], _trump_suit: Card.Suit) -> Array:
	var valid_plays = []
	
	if lead_cards.is_empty():
		for card in hand:
			valid_plays.append([card])
	else:
		if hand.size() > 0:
			valid_plays.append([hand[0]])
	
	return valid_plays

func ai_play_turn(lead_cards: Array[Card], trump_suit: Card.Suit) -> Array[Card]:
	if player_type != PlayerType.AI:
		return []
	
	var valid_plays = get_valid_plays(lead_cards, trump_suit)
	if valid_plays.is_empty():
		return [hand[0]] if hand.size() > 0 else []
	
	return valid_plays[randi() % valid_plays.size()]

func get_hand_size() -> int:
	return hand.size()

func show_cards(face_up: bool = true):
	for card in hand:
		card.set_face_up(face_up)

func set_card_selectable(selectable: bool):
	for card in hand:
		card.is_selectable = selectable

func clear_selection():
	"""清除所有选中的牌"""
	for card in selected_cards:
		card.set_selected(false)
	selected_cards.clear()
	selection_changed.emit(0)
