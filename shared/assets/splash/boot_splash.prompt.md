---
model: nenhum (composição determinística por tools/make_splash.py, sem modelo generativo)
date: 2026-09-06
sources: icon.png, android/icons/brand/rica_solucoes_light.png
post: recorte da moldura arredondada, círculo de 2/3 (a máscara do splash do Android 12), marca a 200 dp
---

# splash / boot_splash

Não é arte gerada: é a tela que a engine desenha entre o splash do sistema e o
menu, montada a partir do ícone do jogo (`icon.png`) e do logo da Rica Soluções
(`android/icons/brand/rica_solucoes_light.png`, o `rica-logo-light` do site).
Fundo azul-marinho `#0b1229`, o mesmo de `boot_splash/bg_color` no
`project.godot` e do `icon_background` do launcher, para a imagem e a cor de
fundo se fundirem em qualquer proporção de tela.

Regenerar: `venv/bin/python tools/make_splash.py`. O `.import` ao lado é
`importer="keep"`: o PNG vai cru para o pacote (a engine o lê com o
`ImageLoader`, antes de haver recursos importados) e não ganha uma cópia
`.ctex` que ninguém usaria.
