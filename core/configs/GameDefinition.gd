## GameDefinition: Resource that defines a game entry for dynamic menu generation.
##
## Use this to register games without hardcoding paths in menu scripts.
## Each GameDefinition holds the display metadata and scene path for a game.
class_name GameDefinition
extends Resource

## Chave de tradução do nome do jogo (`GAME_CONNECT4`, `GAME_GAMAO`...).
##
## Era texto fixo em português — "Quatro em Linha" escrito no catálogo — e o
## CSV tinha uma chave traduzida por jogo que ninguém lia. O aplicativo virava
## para o inglês e os dezenove nomes continuavam em português, no menu, na
## barra de cima e no aviso de maestria. Quem mostra o nome chama
## `display_name()`; `title` sozinho é a chave, e não serve de rótulo.
@export var title: String = ""

## The emoji or icon character displayed alongside the title
@export var icon: String = "🎲"

## Path to the game's main scene file (res://games/...)
@export var scene_path: String = ""

## Category for menu grouping
@export var category: StringName = &"board"

## Brief description (translatable key)
@export var description: String = ""

## Whether this game is fully implemented (false = shows GenericGame placeholder)
@export var is_implemented: bool = true

## Como se joga uma partida. É bandeira, e não escolha única, porque um jogo
## pode ser mais de um: o Gamão e o Nim valem contra a IA e contra outra pessoa
## no mesmo aparelho, e o cartão do menu precisa dizer os dois.
enum Mode {
	SOLO = 1,    ## Sem oponente — quebra-cabeça, paciência, contra o relógio.
	AI = 2,      ## Contra o computador.
	VERSUS = 4,  ## Duas pessoas passando o aparelho.
}

## Gênero curto que aparece na tag do cartão. Chave de tradução, não texto:
## os subtítulos nasceram fixos em português dentro do menu e nunca mudavam de
## idioma junto com o resto da tela.
@export var genre: String = ""

## Bandeira de `Mode`. Zero é "não classificado", e o filtro do menu deixa a
## entrada passar em vez de escondê-la.
@export_flags("Solo", "IA", "2 Jogadores") var modes: int = 0

## Create a GameDefinition with the given parameters
static func create(p_title: String, p_icon: String, p_scene_path: String, p_category: StringName, p_description: String = "", p_implemented: bool = true) -> GameDefinition:
	var def := GameDefinition.new()
	def.title = p_title
	def.icon = p_icon
	def.scene_path = p_scene_path
	def.category = p_category
	def.description = p_description
	def.is_implemented = p_implemented
	return def


## Classifica a entrada e devolve a si mesma, para o catálogo continuar sendo
## uma lista de uma linha por jogo.
func tagged(p_genre: String, p_modes: int) -> GameDefinition:
	genre = p_genre
	modes = p_modes
	return self


## Se a partida aceita este modo. Jogo sem classificação responde `false` — quem
## filtra é que decide o que fazer com isso.
func has_mode(mode: int) -> bool:
	return (modes & mode) != 0


## O nome do jogo no idioma de agora. Use isto em qualquer lugar que o nome
## apareça na tela; `title` é a chave, não o rótulo.
##
## `TranslationServer.translate` em vez de `tr()` porque `Resource` não é `Node`
## e não tem o atalho — é a mesma chamada que `GameMenu.get_game_subtitle` faz.
func display_name() -> String:
	return TranslationServer.translate(title)


## A descrição no idioma de agora, ou vazio quando a entrada não tem chave.
func display_description() -> String:
	return TranslationServer.translate(description) if description != "" else ""
