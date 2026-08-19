extends Control

# Mancala Board Indexing:
# 0-5: Player Pits (Bottom, left to right)
# 6: Player Store (Right)
# 7-12: AI Pits (Top, 12 is top-left, 7 is top-right)
# 13: AI Store (Left)

var pits = []
var is_player_turn: bool = true
var game_over: bool = false

@onready var btn_player_pits = [
	$VBoxContainer/BoardArea/Center/PlayerRow/BtnP0,
	$VBoxContainer/BoardArea/Center/PlayerRow/BtnP1,
	$VBoxContainer/BoardArea/Center/PlayerRow/BtnP2,
	$VBoxContainer/BoardArea/Center/PlayerRow/BtnP3,
	$VBoxContainer/BoardArea/Center/PlayerRow/BtnP4,
	$VBoxContainer/BoardArea/Center/PlayerRow/BtnP5
]
@onready var btn_ai_pits = [
	$VBoxContainer/BoardArea/Center/AIRow/BtnP12,
	$VBoxContainer/BoardArea/Center/AIRow/BtnP11,
	$VBoxContainer/BoardArea/Center/AIRow/BtnP10,
	$VBoxContainer/BoardArea/Center/AIRow/BtnP9,
	$VBoxContainer/BoardArea/Center/AIRow/BtnP8,
	$VBoxContainer/BoardArea/Center/AIRow/BtnP7
]
@onready var btn_player_store = $VBoxContainer/BoardArea/PlayerStore
@onready var btn_ai_store = $VBoxContainer/BoardArea/AIStore
@onready var status_label = $VBoxContainer/StatusLabel
@onready var btn_restart = $VBoxContainer/Actions/BtnRestart

func _ready():
	for i in range(6):
		btn_player_pits[i].pressed.connect(_on_player_pit_clicked.bind(i))
	_start_new_game()

func _start_new_game():
	game_over = false
	is_player_turn = true
	btn_restart.hide()
	
	pits.clear()
	for i in range(14):
		if i == 6 or i == 13:
			pits.append(0) # Stores
		else:
			pits.append(4) # 4 seeds per pit
			
	status_label.text = "Sua Vez! Escolha uma cova para semear."
	_update_ui()

func _update_ui():
	# Player store (right)
	btn_player_store.text = "VOCÊ\n🏆\n%d" % pits[6]
	
	# AI store (left)
	btn_ai_store.text = "IA\n🤖\n%d" % pits[13]
	
	# Player pits (0 to 5)
	for i in range(6):
		var btn = btn_player_pits[i]
		var count = pits[i]
		btn.text = "🌰\n%d" % count
		if is_player_turn and count > 0 and not game_over:
			btn.self_modulate = Color(0.3, 0.7, 0.4)
			btn.disabled = false
		else:
			btn.self_modulate = Color(0.25, 0.2, 0.15)
			btn.disabled = not is_player_turn or count == 0
			
	# AI pits (12 down to 7)
	for i in range(6):
		var pit_idx = 12 - i
		var btn = btn_ai_pits[i]
		btn.text = "🌰\n%d" % pits[pit_idx]
		btn.self_modulate = Color(0.3, 0.25, 0.2)
		btn.disabled = true

func _on_player_pit_clicked(pit_idx: int):
	if game_over or not is_player_turn or pits[pit_idx] == 0:
		return
		
	var extra_turn = _sow_seeds(pit_idx, true)
	_update_ui()
	
	if _check_game_over():
		return
		
	if extra_turn:
		status_label.text = "⭐ Última semente no seu depósito! Turno Extra!"
	else:
		is_player_turn = false
		status_label.text = "Vez da IA..."
		await get_tree().create_timer(0.8).timeout
		_play_ai_turn()

func _sow_seeds(start_pit: int, is_player: bool) -> bool:
	var seeds = pits[start_pit]
	pits[start_pit] = 0
	
	var curr = start_pit
	var opponent_store = 13 if is_player else 6
	var my_store = 6 if is_player else 13
	
	while seeds > 0:
		curr = (curr + 1) % 14
		if curr == opponent_store:
			continue # Skip opponent store
			
		pits[curr] += 1
		seeds -= 1
		
	# Check Extra Turn rule
	var extra_turn = (curr == my_store)
	
	# Check Capture rule: landed in empty pit on own side
	var is_own_side = (curr >= 0 and curr <= 5) if is_player else (curr >= 7 and curr <= 12)
	if is_own_side and pits[curr] == 1 and curr != my_store:
		var opposite = 12 - curr
		if pits[opposite] > 0:
			var captured = pits[curr] + pits[opposite]
			pits[curr] = 0
			pits[opposite] = 0
			pits[my_store] += captured
			if is_player:
				status_label.text = "🎯 Captura! Você pegou %d sementes!" % captured
			else:
				status_label.text = "⚠️ A IA capturou %d sementes suas!" % captured
				
	return extra_turn

func _play_ai_turn():
	if game_over: return
	
	# AI move selection
	var valid_pits = []
	for p in range(7, 13):
		if pits[p] > 0:
			valid_pits.append(p)
			
	if valid_pits.size() == 0:
		_check_game_over()
		return
		
	# Priority 1: Moves giving extra turn
	var chosen_pit = -1
	for p in valid_pits:
		if (p + pits[p]) % 13 == 0: # Lands on pit 13
			chosen_pit = p
			break
			
	# Priority 2: Captures
	if chosen_pit == -1:
		for p in valid_pits:
			var target = (p + pits[p]) % 14
			if target >= 7 and target <= 12 and pits[target] == 0 and pits[12 - target] > 0:
				chosen_pit = p
				break
				
	# Default: Pit with most seeds
	if chosen_pit == -1:
		valid_pits.sort_custom(func(a, b): return pits[a] > pits[b])
		chosen_pit = valid_pits[0]
		
	var extra_turn = _sow_seeds(chosen_pit, false)
	_update_ui()
	
	if _check_game_over():
		return
		
	if extra_turn:
		status_label.text = "IA ganhou um Turno Extra!"
		await get_tree().create_timer(0.9).timeout
		_play_ai_turn()
	else:
		is_player_turn = true
		status_label.text = "Sua Vez! Escolha uma cova."
		_update_ui()

func _check_game_over() -> bool:
	var player_empty = true
	for p in range(0, 6):
		if pits[p] > 0: player_empty = false; break
		
	var ai_empty = true
	for p in range(7, 13):
		if pits[p] > 0: ai_empty = false; break
		
	if player_empty or ai_empty:
		# Sweep remaining seeds
		for p in range(0, 6):
			pits[6] += pits[p]
			pits[p] = 0
		for p in range(7, 13):
			pits[13] += pits[p]
			pits[p] = 0
			
		_update_ui()
		game_over = true
		btn_restart.show()
		
		if pits[6] > pits[13]:
			status_label.text = "🏆 Você Venceu! (%d a %d sementes)" % [pits[6], pits[13]]
		elif pits[13] > pits[6]:
			status_label.text = "IA Venceu! (%d a %d sementes)" % [pits[13], pits[6]]
		else:
			status_label.text = "Empate Perfeito! (%d sementes cada)" % pits[6]
		return true
		
	return false

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")
