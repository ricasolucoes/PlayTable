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
	if btn_restart != null:
		btn_restart.show()
	if player_won and env_3d != null:
		env_3d.celebrate_win()


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
