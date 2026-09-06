# Áudio em arquivo — proveniência

Os arquivos de `core/audio/` entraram em 2026-09-06. Quatro deles vieram da
**YouTube Audio Library** (studio.youtube.com; faixas e efeitos livres para
uso em conteúdo próprio, sem atribuição obrigatória), e o navegador registrou
a origem no próprio arquivo:

| Arquivo | Título na biblioteca | Autor |
|---|---|---|
| `music.mp3` | Ego Chall | Blue Deer Studio |
| `click.mp3` | Pen Clicking | YouTube Audio Library |
| `explosion.mp3` | Big Explosion Cut Off | YouTube Audio Library |
| `splash.mp3` | Water Splash on Cement Series | YouTube Audio Library |

Os demais (`capture`, `card_flip`, `chip_place`, `error`, `flag`, `lose`,
`piece_place`, `shuffle`, `win`, `pop.wav`) foram adicionados na mesma
madrugada por outra ferramenta e chegaram sem registro de origem; presume-se
a mesma biblioteca. Antes de publicar na loja, confirmar.

Como o `AudioManager` os usa: `load()` em tempo de execução, e só quando o
arquivo existe e está importado; sem o arquivo, o som de mesmo nome volta a
ser sintetizado (`AudioManager.gd`, `MusicSynth.gd`) e nada mais muda. A
música toca a -21 dB para todos os climas; as séries longas (viradas de
carta, respingos) são cortadas no primeiro evento (`DURACAO_MAXIMA`).
`pop.wav` não é usado.
