class_name BaseGame
extends Control

## Ciclo de vida comum aos 16 jogos: voltar ao menu, reiniciar a partida e
## encerrar o jogo.
##
## Aqui mora só o que era idêntico em todos eles — o botão voltar tinha 13
## cópias, o reiniciar 11 e o encerramento 8, todas terminando do mesmo jeito.
## A partida em si (montar o tabuleiro, aplicar as regras, mover as peças)
## continua sendo de cada jogo: esta classe não guarda estado de partida nem
## bandeira nenhuma para acomodar exceção.
##
## Contrato para quem herda:
##
##   - `_ready()` preenche os nós que o jogo tem (`status_label`, `btn_restart`,
##     `env_3d`) e ajusta `menu_scene_path` quando o jogo é de cartas. Todos são
##     opcionais: os ajudantes abaixo simplesmente não fazem nada sem eles.
##   - `_start_new_game()` é o ponto de reinício, chamado pelo botão reiniciar.
##   - `finish_game()` é o final de partida; a assinatura do `_end_game` de cada
##     jogo continua sendo dele.

const MENU_TABULEIRO := "res://core/telas/MenuTabuleiro.tscn"
const MENU_CARTAS := "res://core/telas/MenuCartas.tscn"

## Menu para onde o botão voltar leva. Os jogos de cartas trocam para MENU_CARTAS.
var menu_scene_path: String = MENU_TABULEIRO

## Verdadeiro depois que a partida termina. Trava a entrada de jogadas.
var game_over: bool = false

## Rótulo de status da partida, quando o jogo tem um.
var status_label: Label = null

## Botão de reiniciar, quando o jogo tem um. `finish_game()` o revela.
var btn_restart: BaseButton = null

## Mesa 3D, quando o jogo tem uma. `finish_game()` comemora nela.
var env_3d: TabletopEnvironment3D = null

## Identificador do jogo no barramento de eventos, tirado da pasta da cena
## (`res://games/gamao/BackgammonGame.tscn` -> `gamao`).
var game_id: String = ""

## Trava para o resultado nao ser contado duas vezes na mesma partida: varios
## jogos chamam `finish_game()` de mais de um caminho de fim.
var _result_reported: bool = false


## O raiz de cada jogo é uma Control de tela inteira. No filtro padrão ela
## retém o clique, e ele nunca chega ao Picker do Board3D — foi assim que as
## Damas, o único jogo que entra por picking 3D, ficaram sem clique depois do
## merge que apagou a grade 2D delas. Os botões da HUD continuam recebendo o
## toque: o filtro do pai não impede os filhos. Fica no `_init` porque o Godot
## não encadeia `_ready` entre pai e filho, e os 16 jogos têm o próprio.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Liga a gamificacao sem que nenhum dos 19 jogos precise saber dela.
##
## O motor (GamificationManager, XP, nivel, streak, conquistas) ja existia e
## escutava o GameEventBus, mas so tres jogos publicavam alguma coisa nele e
## nada aparecia na tela: era gamificacao invisivel. Aqui a cena ganha o aviso
## visual, e `finish_game()` passa a publicar o resultado da partida.
func _enter_tree() -> void:
	game_id = _derive_game_id()
	if get_node_or_null("RewardToast") == null:
		var toast := RewardToast.new()
		toast.name = "RewardToast"
		add_child(toast)


func _derive_game_id() -> String:
	var path := scene_file_path
	if path.begins_with("res://games/"):
		var parts := path.split("/")
		if parts.size() >= 4:
			return parts[3]
	return "playtable"


# ------------------------------------------------------------ enquadramento

## Folga entre a HUD e a borda do tabuleiro, em pixels do viewport logico.
const HUD_GAP := 10.0

var _fit_size: Vector2 = Vector2.ZERO
var _fit_center: Vector3 = Vector3.ZERO
var _refit_pending: bool = false


## Enquadra a mesa no espaco que a HUD deixa livre.
##
## Regra da casa: o jogo ocupa a tela. Sem isto a camera usa o enquadramento
## padrao de 6x6 unidades para qualquer conteudo -- um tabuleiro de damas de 6,4
## fica cortado nas laterais e um monte de descarte de uma carta so fica do
## tamanho de uma unha, com metade da tela em feltro vazio.
##
## A faixa util nao e um numero escrito a mao: sai da HUD que a cena realmente
## tem. Mexer no cabecalho ou nos botoes reenquadra sozinho.
func fit_table(content_size: Vector2, center: Vector3 = Vector3.ZERO) -> void:
	_fit_size = content_size
	_fit_center = center
	if env_3d == null:
		return
	_apply_fit()
	# No `_ready` os Control ainda nao tem retangulo: o container de baixo ainda
	# mede a tela inteira e a HUD sairia com 1260 px de altura. Refaz a conta
	# depois do primeiro passe de layout, e sempre que a janela mudar.
	_schedule_refit()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_apply_fit):
		vp.size_changed.connect(_apply_fit)


func _apply_fit() -> void:
	if env_3d == null or _fit_size == Vector2.ZERO:
		return
	var bandas := measure_hud_bands()
	env_3d.set_safe_area(bandas.x, bandas.y)
	env_3d.frame_content(_fit_size, _fit_center)


func _schedule_refit() -> void:
	if _refit_pending or not is_inside_tree():
		return
	_refit_pending = true
	await get_tree().process_frame
	await get_tree().process_frame
	_refit_pending = false
	if is_instance_valid(self) and is_inside_tree():
		_apply_fit()


## Quanto a HUD come em cima e embaixo, em pixels do viewport logico.
##
## Conta so os blocos de HUD de primeiro nivel -- os que a propria cena ancora
## ao topo (`anchor_bottom == 0`) ou ao rodape (`anchor_top == 1`). O que esta
## dentro de um Container nao entra: quem posiciona esses e o container, e as
## ancoras deles ficam em zero mesmo quando o bloco esta colado no rodape. Era
## por isso que um botao de "Pedir Carta" no pe da tela era lido como HUD de
## topo de 1260 px de altura.
func measure_hud_bands() -> Vector2:
	var vp := get_viewport_rect().size
	if vp.y <= 0.0:
		return Vector2(HUD_GAP, HUD_GAP)
	return _scan_hud(self, vp.y) + Vector2(HUD_GAP, HUD_GAP)


## Devolve (topo, rodape). Vector2 anda por valor no GDScript, entao a soma sobe
## pelo retorno -- passar um acumulador nao funcionaria.
func _scan_hud(node: Node, altura: float) -> Vector2:
	var bandas := Vector2.ZERO
	for child in node.get_children():
		if child is CanvasLayer:
			continue                       # o aviso de recompensa nao e HUD fixa
		if child is Control:
			var ctrl := child as Control
			if not ctrl.visible or ctrl.name.begins_with("Touch"):
				continue
			if not (node is Container):
				var r := ctrl.get_global_rect()
				if r.size.x > 0.0 and r.size.y > 0.0:
					if ctrl.anchor_top <= 0.001 and ctrl.anchor_bottom <= 0.001:
						bandas.x = maxf(bandas.x, r.end.y)
						continue           # o bloco ja foi medido inteiro
					elif ctrl.anchor_top >= 0.999 and ctrl.anchor_bottom >= 0.999:
						bandas.y = maxf(bandas.y, altura - r.position.y)
						continue
		var filho := _scan_hud(child, altura)
		bandas.x = maxf(bandas.x, filho.x)
		bandas.y = maxf(bandas.y, filho.y)
	return bandas


# ---------------------------------------------------------------- navegação

## Ligado no `.tscn` de 13 jogos.
func _on_btn_back_pressed() -> void:
	go_back_to_menu()


## Mesmo botão, nome que 3 cenas usam.
func _on_back_pressed() -> void:
	go_back_to_menu()


func go_back_to_menu() -> void:
	play_click()
	SceneManager.goto_scene(menu_scene_path)


# ----------------------------------------------------------------- reinício

## Ligado no `.tscn` de 11 jogos.
func _on_btn_restart_pressed() -> void:
	restart_game()


## Mesmo botão, nome que 3 cenas usam.
func _on_restart_pressed() -> void:
	restart_game()


func restart_game() -> void:
	play_click()
	_result_reported = false
	_start_new_game()


## Recomeça a partida. Cada jogo sobrescreve.
func _start_new_game() -> void:
	pass


# ------------------------------------------------------------ fim de partida

## Fecha a partida: trava a entrada, anuncia o resultado, libera o reiniciar e
## comemora quando o jogador venceu.
func finish_game(message: String, player_won: bool = false) -> void:
	game_over = true
	set_status(message)
	report_match_result(player_won)
	if btn_restart != null:
		btn_restart.show()
	if player_won and env_3d != null:
		env_3d.celebrate_win()


## Publica o fim de partida no barramento: dai saem o XP, a streak do dia, as
## conquistas e o aviso na tela. Jogos que terminam por modal em vez de
## `finish_game()` -- o Jogo da Velha e um -- chamam isto direto.
##
## Ignora chamadas repetidas na mesma partida; `_start_new_game()` de cada jogo
## nao precisa lembrar de destravar, quem destrava e `restart_game()`.
func report_match_result(player_won: bool, extra: Dictionary = {}) -> void:
	if _result_reported:
		return
	_result_reported = true
	if GameEventBus == null:
		return
	var payload := extra.duplicate()
	payload["win"] = player_won
	payload.merge(_close_difficulty(player_won, bool(payload.get("draw", false))))
	GameEventBus.emit_match_completed(game_id, payload)


## Fecha a partida na escada de dificuldade e devolve o que a gamificacao
## precisa saber dela.
##
## Todo jogo anda na escada, tenha IA ou nao: `difficulty` conta ao XP que a
## partida valia (o `xp_scale`), e `difficulty_delta` diz para a HUD se o
## degrau subiu ou desceu. Quem consome o degrau para escolher a jogada da IA
## e cada jogo, no proprio `_ready()`.
func _close_difficulty(player_won: bool, draw: bool) -> Dictionary:
	if DifficultyManager == null:
		return {}
	var delta := DifficultyManager.register_result(game_id, player_won, draw)
	var nivel := DifficultyManager.get_level(game_id)
	return {
		"difficulty": nivel,
		"difficulty_delta": delta,
		"xp_scale": DifficultyManager.xp_scale(nivel - delta),
	}


## Revela o modal de resultado com o fade que os jogos 2D repetiam.
func reveal_result_modal(modal: Control, delay: float = 0.6) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(modal):
		return
	modal.visible = true
	modal.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(modal, "modulate:a", 1.0, 0.3)


# ------------------------------------------------------------------ auxiliares

func set_status(text: String) -> void:
	if status_label != null and text != "":
		status_label.text = text


func play_click() -> void:
	if AudioManager:
		AudioManager.play_click()
