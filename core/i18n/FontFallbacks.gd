class_name FontFallbacks
extends RefCounted

## Emoji e simbolos da interface (robo do modo, trofeu, naipes, setas de
## desfazer) nao existem na fonte padrao da engine. No desktop o sistema
## empresta o glifo; no iOS nao ha esse emprestimo e o botao saia vazio. As
## fontes ficam no pacote e entram como fallback da fonte padrao, antes de
## qualquer tela desenhar.

const ARQUIVOS := [
	"res://shared/assets/fonts/NotoEmoji.ttf",
	"res://shared/assets/fonts/NotoSansSymbols2-Regular.ttf",
	"res://shared/assets/fonts/NotoSansSymbols-Misc.ttf",
	"res://shared/assets/fonts/NotoSansMath-Arrows.ttf",
]


static func aplicar() -> void:
	var base: Font = ThemeDB.fallback_font
	if base == null:
		return
	var lista: Array[Font] = base.fallbacks.duplicate()
	for caminho: String in ARQUIVOS:
		var fonte := load(caminho) as Font
		if fonte != null and not lista.has(fonte):
			lista.append(fonte)
	base.fallbacks = lista
