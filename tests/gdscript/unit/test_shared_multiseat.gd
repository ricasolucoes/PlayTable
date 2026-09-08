extends GutTest

## Os modulos compartilhados das mesas de N assentos: SeatTable (quem senta
## onde), MatchSync (semente e jogadas pela rede), TrickEngine (vazas),
## MeldFinder (trincas e sequencias), CardTable3D (a mesa de cartas) e
## DiceTray3D (a bandeja de dados).
##
## Nasceram para os 17 jogos novos nao repetirem o que e igual entre eles.
## A rede aqui e a mesma da suite de rede: `_test_activate()` no lugar do peer.

const ENV_3D := preload("res://shared/3d/TabletopEnvironment3D.tscn")


func after_each() -> void:
	NetworkManager.leave()


# ---------------------------------------------------------------- SeatTable

func test_fora_da_rede_a_cadeira_zero_e_a_pessoa_e_o_resto_e_maquina() -> void:
	var mesa := SeatTable.build(4, false, 0, true)
	assert_true(mesa.is_local(0), "0 e a pessoa daqui")
	for i in [1, 2, 3]:
		assert_true(mesa.is_ai(i), "%d e maquina" % i)
		assert_true(mesa.ai_runs_here(i), "e a maquina pensa aqui")
	assert_false(mesa.online(), "sem rede")
	assert_eq(mesa.local_index(), 0, "a pessoa esta na 0")
	assert_eq(mesa.remote_index(), -1, "ninguem do outro lado")


func test_passa_e_joga_poe_pessoas_ao_lado_nas_outras_cadeiras() -> void:
	var mesa := SeatTable.build(3, false, 0, false)
	assert_true(mesa.is_pass(1) and mesa.is_pass(2), "as outras sao pessoas ao lado")
	assert_true(mesa.pass_and_play(), "e passa-e-joga")
	assert_true(mesa.acts_here(2), "e a jogada delas nasce aqui")
	assert_eq(mesa.human_count(), 3, "tres pessoas")


func test_em_rede_o_anfitriao_e_a_zero_e_o_convidado_a_um() -> void:
	var host := SeatTable.build(4, true, 1, true)
	assert_true(host.is_local(0) and host.is_remote(1), "no anfitriao: eu na 0, ele na 1")
	assert_true(host.is_host(), "e anfitriao")
	assert_true(host.ai_runs_here(2), "o anfitriao pensa pela maquina")
	assert_true(host.expects_from_network(1), "e espera a jogada do convidado pela rede")

	var guest := SeatTable.build(4, true, 2, true)
	assert_true(guest.is_remote(0) and guest.is_local(1), "no convidado: ele na 0, eu na 1")
	assert_false(guest.is_host(), "nao e anfitriao")
	assert_false(guest.ai_runs_here(2), "o convidado nao pensa pela maquina")
	assert_true(guest.expects_from_network(2), "as jogadas dela chegam pela rede")
	assert_true(guest.expects_from_network(0), "e as do anfitriao tambem")
	assert_false(guest.expects_from_network(1), "a minha nasce aqui")


func test_ordem_duplas_e_adversarios() -> void:
	var mesa := SeatTable.build(4, false, 0)
	assert_eq(mesa.next(3), 0, "da 3 volta para a 0")
	assert_eq(mesa.next(0, -1), 3, "anti-horario")
	assert_eq(mesa.partner_of(0), 2, "0 joga com 2")
	assert_eq(mesa.partner_of(3), 1, "3 joga com 1")
	assert_eq(mesa.team_of(2), 0, "mesmo time")
	assert_eq(mesa.opponents_of(0), [1, 3] as Array[int], "adversarios da 0")
	var tres := SeatTable.build(3, false, 0)
	assert_eq(tres.partner_of(0), -1, "sem duplas na mesa de tres")
	assert_eq(tres.opponents_of(0), [1, 2] as Array[int], "todos contra todos")


# ---------------------------------------------------------------- MatchSync

class JogoDeMentira extends BaseGame:
	pass


func _jogo() -> BaseGame:
	var j := JogoDeMentira.new()
	add_child_autofree(j)
	return j


func test_fora_da_rede_o_sync_e_inerte_mas_sorteia() -> void:
	var jogo := _jogo()
	var mesa := SeatTable.build(4, false, 0)
	var sync := MatchSync.new(jogo, mesa)
	sync.start()
	assert_false(sync.waiting_for_deal(), "nao espera ninguem")
	assert_true(sync.seeded(), "tem semente")
	sync.send(0, {"x": 1})
	assert_true(sync.accept({"t": "act", "seat": 1, "a": {}}).is_empty(), "nada entra fora da rede")


func test_o_anfitriao_manda_a_semente_e_o_convidado_a_recebe() -> void:
	NetworkManager._test_activate("playtable", 1)
	var jogo := _jogo()
	var mesa := SeatTable.for_game(jogo, 4)
	var sync := MatchSync.new(jogo, mesa)
	sync.start()
	assert_false(sync.waiting_for_deal(), "o anfitriao nao espera")
	assert_eq(NetworkManager.sent_moves.size(), 1, "mandou uma coisa")
	assert_eq(str(NetworkManager.sent_moves[0]["t"]), "deal", "a semente")
	var semente := int(NetworkManager.sent_moves[0]["seed"])
	assert_ne(semente, 0, "semente de verdade")

	# O pedido do convidado que chegou atrasado: o anfitriao repete a mesma.
	assert_true(sync.accept({"t": "need_deal"}).is_empty(), "o pedido nao vira jogada")
	assert_eq(NetworkManager.sent_moves.size(), 2, "e foi respondido")
	assert_eq(int(NetworkManager.sent_moves[1]["seed"]), semente, "com a MESMA semente")

	# A jogada da maquina do anfitriao sai; a do convidado nao sai daqui.
	sync.send(2, {"c": 5})
	assert_eq(NetworkManager.sent_moves.size(), 3, "a maquina daqui viaja")
	sync.send(1, {"c": 5})
	assert_eq(NetworkManager.sent_moves.size(), 3, "a cadeira do outro nao sai daqui")

	NetworkManager.leave()
	NetworkManager._test_activate("playtable", 2)
	var jogo2 := _jogo()
	var mesa2 := SeatTable.for_game(jogo2, 4)
	var sync2 := MatchSync.new(jogo2, mesa2)
	sync2.start()
	assert_true(sync2.waiting_for_deal(), "o convidado espera")
	assert_true(NetworkManager.sent_moves.size() >= 1, "e pediu")
	assert_eq(str(NetworkManager.sent_moves[0]["t"]), "need_deal", "o pedido")
	var msg := sync2.accept({"t": "deal", "seed": semente})
	assert_eq(str(msg.get("t", "")), "deal", "a semente entrou")
	assert_false(sync2.waiting_for_deal(), "e a espera acabou")
	assert_true(sync2.accept({"t": "deal", "seed": 99}).is_empty(), "uma segunda semente e ignorada")
	assert_eq(sync2.seed, semente, "a primeira ficou")
	var act := sync2.accept({"t": "act", "seat": 2, "a": {"c": 5}})
	assert_eq(int(act.get("seat", -1)), 2, "a maquina do anfitriao entra")
	assert_true(sync2.accept({"t": "act", "seat": 1, "a": {}}).is_empty(), "a minha cadeira nao entra pela rede")


func test_a_mesma_semente_embaralha_igual_nos_dois_lados() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 4242
	var b := RandomNumberGenerator.new()
	b.seed = 4242
	var x := range(20)
	var y := range(20)
	MatchSync.shuffle_with(x, a)
	MatchSync.shuffle_with(y, b)
	assert_eq(x, y, "mesma ordem")
	assert_ne(x, range(20), "e embaralhada de verdade")


# -------------------------------------------------------------- TrickEngine

func _c(v: int, s: int) -> Card:
	return Card.new(v, s)


func test_quem_tem_o_naipe_puxado_e_obrigado_a_segui_lo() -> void:
	var vaza := TrickEngine.new(4, TrickEngine.ace_high)
	vaza.begin(0)
	assert_eq(vaza.current_seat(), 0, "sai a 0")
	assert_true(vaza.play(0, _c(9, Card.Suit.HEARTS)), "saiu de copas")
	assert_false(vaza.play(0, _c(2, Card.Suit.HEARTS)), "fora de vez nao")
	var mao := [_c(3, Card.Suit.SPADES), _c(5, Card.Suit.HEARTS), _c(13, Card.Suit.CLUBS)]
	var legais := vaza.legal_cards(mao)
	assert_eq(legais.size(), 1, "so a de copas")
	assert_eq(legais[0].value, 5, "o 5 de copas")
	var sem_copas := [_c(3, Card.Suit.SPADES), _c(13, Card.Suit.CLUBS)]
	assert_eq(vaza.legal_cards(sem_copas).size(), 2, "sem o naipe, qualquer uma")


func test_o_trunfo_corta_e_a_maior_do_naipe_puxado_leva() -> void:
	var vaza := TrickEngine.new(4, TrickEngine.ace_high, Card.Suit.SPADES)
	vaza.begin(2)
	vaza.play(2, _c(10, Card.Suit.HEARTS))
	vaza.play(3, _c(1, Card.Suit.HEARTS))
	vaza.play(0, _c(2, Card.Suit.SPADES))
	vaza.play(1, _c(13, Card.Suit.DIAMONDS))
	assert_true(vaza.is_complete(), "quatro cartas")
	assert_eq(vaza.winner(), 0, "o 2 de espadas (trunfo) leva")
	assert_false(vaza.tied(), "sem empate")

	var sem_trunfo := TrickEngine.new(4, TrickEngine.ace_high)
	sem_trunfo.begin(2)
	sem_trunfo.play(2, _c(10, Card.Suit.HEARTS))
	sem_trunfo.play(3, _c(1, Card.Suit.HEARTS))
	sem_trunfo.play(0, _c(2, Card.Suit.SPADES))
	sem_trunfo.play(1, _c(13, Card.Suit.DIAMONDS))
	assert_eq(sem_trunfo.winner(), 3, "o as de copas leva; o rei de ouros nao concorre")


func test_sem_seguir_naipe_a_forca_sozinha_decide_e_pode_empatar() -> void:
	var forca := func(c: Card) -> int: return c.value
	var vaza := TrickEngine.new(2, forca, Card.Suit.NONE, false)
	vaza.begin(0)
	vaza.play(0, _c(7, Card.Suit.HEARTS))
	vaza.play(1, _c(7, Card.Suit.CLUBS))
	assert_true(vaza.tied(), "duas cartas iguais empatam")
	assert_eq(vaza.winner(), 0, "e a primeira fica na frente")
	assert_eq(vaza.points(func(c: Card) -> int: return c.value), 14, "os pontos somam")


# --------------------------------------------------------------- MeldFinder

func test_trinca_e_sequencia_basicas() -> void:
	assert_true(MeldFinder.is_set([_c(7, 1), _c(7, 2), _c(7, 3)]), "trinca de 7")
	assert_false(MeldFinder.is_set([_c(7, 1), _c(7, 1), _c(7, 3)]), "naipe repetido nao e trinca")
	assert_true(MeldFinder.is_set([_c(7, 1), _c(7, 1), _c(7, 3)], {"distinct_suits": false}),
		"a menos que a regra deixe")
	assert_true(MeldFinder.is_run([_c(4, 2), _c(5, 2), _c(6, 2)]), "4-5-6 de ouros")
	assert_false(MeldFinder.is_run([_c(4, 2), _c(5, 3), _c(6, 2)]), "naipe misturado nao")
	assert_false(MeldFinder.is_run([_c(4, 2), _c(6, 2), _c(7, 2)]), "com buraco nao")
	assert_true(MeldFinder.is_run([_c(1, 4), _c(2, 4), _c(3, 4)]), "as baixo")
	assert_true(MeldFinder.is_run([_c(12, 4), _c(13, 4), _c(1, 4)]), "as alto")
	assert_false(MeldFinder.is_run([_c(13, 4), _c(1, 4), _c(2, 4)]), "sem dar a volta")


func test_curinga_tapa_o_buraco_dentro_do_limite() -> void:
	var opts := {"is_wild": func(c: Card) -> bool: return c.value == 2, "max_wilds": 1}
	assert_true(MeldFinder.is_run([_c(4, 2), _c(2, 1), _c(6, 2)], opts), "o 2 tapa o 5")
	assert_false(MeldFinder.is_run([_c(4, 2), _c(2, 1), _c(2, 3)], opts), "dois curingas passam do limite")
	assert_true(MeldFinder.is_set([_c(9, 1), _c(9, 3), _c(2, 4)], opts), "trinca com curinga")
	assert_false(MeldFinder.is_clean([_c(9, 1), _c(9, 3), _c(2, 4)], opts), "suja")
	assert_true(MeldFinder.is_canasta([_c(3, 1), _c(4, 1), _c(5, 1), _c(6, 1), _c(7, 1), _c(8, 1), _c(9, 1)], opts),
		"sete seguidas sao canastra")


func test_nove_cartas_do_pife_fecham_em_tres_jogos() -> void:
	var mao := [
		_c(5, 1), _c(5, 2), _c(5, 3),
		_c(9, 4), _c(10, 4), _c(11, 4),
		_c(12, 2), _c(13, 2), _c(1, 2),
	]
	mao.shuffle()
	var jogos := MeldFinder.partition(mao, 3)
	assert_eq(jogos.size(), 3, "tres jogos")
	assert_true(MeldFinder.can_go_out(mao), "bate")
	mao[0] = _c(3, 3)
	var quebrada := mao.duplicate()
	assert_true(MeldFinder.partition(quebrada, 3).is_empty() or not MeldFinder.can_go_out(quebrada)
		or MeldFinder.can_go_out(quebrada), "com uma carta trocada pode ou nao fechar -- so nao pode estourar")


func test_best_melds_cobre_o_maximo_e_deixa_o_resto() -> void:
	var mao := [_c(5, 1), _c(5, 2), _c(5, 3), _c(9, 4), _c(10, 4), _c(11, 4), _c(3, 3), _c(8, 1)]
	var r := MeldFinder.best_melds(mao)
	assert_eq((r["melds"] as Array).size(), 2, "dois jogos")
	assert_eq((r["deadwood"] as Array).size(), 2, "duas sobras")


# -------------------------------------------------------------- CardTable3D

func test_a_mesa_de_cartas_distribui_e_conhece_as_cadeiras() -> void:
	var jogo := _jogo()
	var env: TabletopEnvironment3D = ENV_3D.instantiate()
	jogo.add_child(env)
	var mesa := CardTable3D.new()
	jogo.add_child(mesa)
	mesa.setup(jogo, 4, env)
	assert_not_null(mesa.picker, "tem picker")
	assert_eq(mesa.picker.get_parent(), jogo, "pendurado na cena")

	var baralho := Deck.create_standard_52()
	for i in 3:
		mesa.add_card(0, baralho.draw(), true)
		mesa.add_card(2, baralho.draw(), false)
	assert_eq(mesa.hand_size(0), 3, "tres na minha mao")
	assert_eq(mesa.hand_size(2), 3, "tres na do outro")
	assert_eq(mesa.hand_size(1), 0, "nada na 1")
	var carta := mesa.model_at(0, 1)
	assert_true(carta is Card, "a carta do modelo esta na carta da mesa")
	assert_eq(mesa.index_of(0, carta), 1, "e se acha pelo modelo")

	var baixo := mesa.seat_anchor(0)
	var cima := mesa.seat_anchor(2)
	assert_gt(float(Vector3(baixo["pos"]).z), 0.0, "a 0 fica embaixo (z positivo)")
	assert_lt(float(Vector3(cima["pos"]).z), 0.0, "a 2 fica em cima")
	assert_lt(float(Vector3(mesa.seat_anchor(1)["pos"]).x), 0.0, "a 1 fica a esquerda")
	assert_gt(float(Vector3(mesa.seat_anchor(3)["pos"]).x), 0.0, "a 3 a direita")

	var a := mesa.slot(0, 0, 3)
	var b := mesa.slot(0, 2, 3)
	assert_lt(a.x, b.x, "o leque cresce para a direita")
	assert_almost_eq(mesa.slot(0, 1, 3).x, 0.0, 0.001, "centrado")

	var jogada := mesa.play_to_center(0, 1)
	assert_not_null(jogada, "a carta foi ao centro")
	assert_eq(mesa.hand_size(0), 2, "e saiu da mao")
	assert_eq(mesa.center.size(), 1, "uma no centro")
	mesa.collect_center(2)
	assert_eq(mesa.center.size(), 0, "o centro esvaziou")

	mesa.discard(0, 0)
	assert_eq(mesa.discard_pile.size(), 1, "uma no descarte")
	assert_true(mesa.top_discard() is Card, "e se le o topo")
	mesa.clear_all()
	assert_eq(mesa.hand_size(2), 0, "limpou")


func test_o_rank_e_o_naipe_da_carta_batem_com_o_atlas() -> void:
	assert_eq(CardTable3D.face_of(_c(1, Card.Suit.HEARTS)), ["A", CardArt2D.SUIT_HEART], "as de copas")
	assert_eq(CardTable3D.face_of(_c(14, Card.Suit.SPADES)), ["A", CardArt2D.SUIT_SPADE], "as alto")
	assert_eq(CardTable3D.face_of(_c(13, Card.Suit.CLUBS)), ["K", CardArt2D.SUIT_CLUB], "rei de paus")
	assert_eq(CardTable3D.face_of(_c(10, Card.Suit.DIAMONDS)), ["10", CardArt2D.SUIT_DIAMOND], "dez de ouros")


# --------------------------------------------------------------- DiceTray3D

func test_a_bandeja_enfileira_e_segura_dados() -> void:
	var bandeja := DiceTray3D.new()
	add_child_autofree(bandeja)
	bandeja.setup(5)
	assert_eq(bandeja.count(), 5, "cinco dados")
	assert_eq(bandeja.positions().size(), 5, "cinco alvos")
	assert_lt(float(bandeja.positions()[0].x), float(bandeja.positions()[4].x), "em fila")
	bandeja.set_held(1, true)
	bandeja.toggle_held(3)
	assert_eq(bandeja.held_indices(), [1, 3] as Array[int], "dois presos")
	bandeja.set_values_immediate([6, 5, 4, 3, 2])
	assert_eq(bandeja.values, [6, 5, 4, 3, 2] as Array[int], "os valores")
	var sorteio := DiceTray3D.random_values(5)
	assert_eq(sorteio.size(), 5, "cinco sorteados")
	for v in sorteio:
		assert_true(int(v) >= 1 and int(v) <= 6, "entre 1 e 6")
	bandeja.release_all()
	assert_true(bandeja.held_indices().is_empty(), "todos soltos")
