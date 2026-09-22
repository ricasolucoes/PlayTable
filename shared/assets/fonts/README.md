# Fontes de fallback (emoji e símbolos)

Entram como fallback da fonte padrão em `core/i18n/FontFallbacks.gd`. No iOS
não existe fallback de sistema e todo emoji da interface saía em branco.

| Arquivo | Origem | Licença |
|---|---|---|
| `NotoEmoji.ttf` | google/fonts `ofl/notoemoji/NotoEmoji[wght].ttf` | OFL 1.1 |
| `NotoSansSymbols2-Regular.ttf` | google/fonts `ofl/notosanssymbols2/` | OFL 1.1 |
| `NotoSansSymbols-Misc.ttf` | `ofl/notosanssymbols/NotoSansSymbols[wght].ttf`, só U+2600–26FF | OFL 1.1 |
| `NotoSansMath-Arrows.ttf` | `ofl/notosansmath/NotoSansMath-Regular.ttf`, só U+2190–21FF | OFL 1.1 |

Baixadas em 2026-09-22. Os subconjuntos saíram do `pyftsubset` (fontTools).

**Métricas verticais reescritas** (hhea, OS/2 typo e win): ascent 30/28 em e
descent 9/28 em, as mesmas da fonte padrão do Godot. O `Font.get_height()` do
Godot pega o máximo entre a fonte e os fallbacks; com as métricas originais a
linha de 28 px ia de 39 para 58 px e toda barra, célula e rótulo do jogo
engordava. O desenho do glifo não é recortado pelas métricas.
