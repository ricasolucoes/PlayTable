#!/usr/bin/env python3
"""Gera os icones de launcher do Android a partir de icon.png.

Por que existe: o APK e o AAB nao passam pelo exportador do Godot -- os scripts
de build fazem `--export-pack` e chamam o gradle direto. O exportador e quem
escreveria os launcher icons em android/build/res/mipmap-*; sem ele o pacote
sai com os icones que vem dentro do godot-lib.aar, o robo do Godot. Foi por
isso que "o icone nao aparece" no aparelho.

Saida (versionada em android/icons/, copiada por android/icons/install.sh):

  mipmap-<dpi>-v4/icon.png             legado, 48..192 px, cantos transparentes
  mipmap-<dpi>-v4/icon_background.png  camada de fundo do icone adaptativo
  mipmap-<dpi>-v4/icon_foreground.png  camada da arte, dentro da zona segura
  mipmap-<dpi>-v4/icon_monochrome.png  silhueta para o icone tematico (Android 13+)

Uso: venv/bin/python tools/make_launcher_icons.py
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTE = os.path.join(RAIZ, "icon.png")
SAIDA = os.path.join(RAIZ, "android", "icons")

# Densidades e os tamanhos que o Android espera em cada uma.
DENSIDADES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}

# Cor do fundo da arte, medida no proprio icon.png (o azul-marinho por tras das
# cartas e do dado). A camada de fundo do icone adaptativo usa a mesma, para a
# moldura arredondada da arte sumir nela.
FUNDO = (11, 18, 41, 255)

# A arte ocupa 78% do canvas adaptativo: a zona segura do Android e 66/108
# (61%), e o que fica de fora da zona e a moldura arredondada, que tem a cor do
# fundo e pode ser cortada sem perda.
ESCALA_ARTE = 0.78


def _raio_do_arredondado(im: Image.Image) -> int:
    """Distancia do canto ate a arte, medida na diagonal, virada em raio."""
    w = im.size[0]
    d = 0
    for i in range(w // 2):
        r, g, b, _ = im.getpixel((i, i))
        if not (r > 235 and g > 235 and b > 235):
            d = i
            break
    # Na diagonal o arco de raio R comeca em R * (1 - 1/sqrt(2)) do canto.
    return int(round(d / (1.0 - 0.70710678))) if d > 0 else 0


def _mascara_arredondada(tamanho: int, raio: int) -> Image.Image:
    escala = 4
    grande = Image.new("L", (tamanho * escala, tamanho * escala), 0)
    ImageDraw.Draw(grande).rounded_rectangle(
        (0, 0, tamanho * escala - 1, tamanho * escala - 1), radius=raio * escala, fill=255)
    return grande.resize((tamanho, tamanho), Image.LANCZOS)


def _arte_recortada(im: Image.Image) -> Image.Image:
    """O icone com os cantos brancos trocados por transparencia."""
    raio = _raio_do_arredondado(im)
    recorte = im.copy()
    recorte.putalpha(_mascara_arredondada(im.size[0], raio))
    return recorte


def _silhueta(arte: Image.Image) -> Image.Image:
    """Branco onde ha arte sobre o fundo, transparente no resto.

    O icone tematico do Android 13 pinta a silhueta com a cor do tema; ela tem
    de ler como forma, entao entra so o que se destaca do azul-marinho.
    """
    w, h = arte.size
    # A borda anti-serrilhada da moldura arredondada e clara e viraria um arco
    # solto na silhueta: a mascara encolhe alguns pixels antes da contagem.
    raio = _raio_do_arredondado(arte)
    encolhida = Image.new("L", (w, h), 0)
    borda = max(6, w // 64)
    ImageDraw.Draw(encolhida).rounded_rectangle(
        (borda, borda, w - 1 - borda, h - 1 - borda), radius=max(1, raio - borda), fill=255)
    arte = arte.copy()
    arte.putalpha(encolhida)
    saida = Image.new("LA", (w, h), (255, 0))
    px_in = arte.load()
    px_out = saida.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px_in[x, y]
            if a == 0:
                continue
            dist = abs(r - FUNDO[0]) + abs(g - FUNDO[1]) + abs(b - FUNDO[2])
            if dist > 120:
                px_out[x, y] = (255, min(255, int(a * min(1.0, (dist - 120) / 160.0 + 0.35))))
    return saida.filter(ImageFilter.GaussianBlur(1.2)).convert("RGBA")


def _camada(arte: Image.Image, lado: int) -> Image.Image:
    """A arte centrada num canvas transparente, na escala da zona segura."""
    canvas = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    alvo = int(round(lado * ESCALA_ARTE))
    menor = arte.resize((alvo, alvo), Image.LANCZOS)
    canvas.alpha_composite(menor, ((lado - alvo) // 2, (lado - alvo) // 2))
    return canvas


def main() -> int:
    if not os.path.exists(FONTE):
        print(f"icon.png nao encontrado em {FONTE}", file=sys.stderr)
        return 1
    fonte = Image.open(FONTE).convert("RGBA")
    if fonte.size[0] != fonte.size[1]:
        print("icon.png precisa ser quadrado", file=sys.stderr)
        return 1

    arte = _arte_recortada(fonte)
    silhueta = _silhueta(arte)

    for dpi, (legado, adaptativo) in DENSIDADES.items():
        pasta = os.path.join(SAIDA, f"mipmap-{dpi}-v4")
        os.makedirs(pasta, exist_ok=True)
        arte.resize((legado, legado), Image.LANCZOS).save(os.path.join(pasta, "icon.png"), optimize=True)
        Image.new("RGBA", (adaptativo, adaptativo), FUNDO).save(
            os.path.join(pasta, "icon_background.png"), optimize=True)
        _camada(arte, adaptativo).save(os.path.join(pasta, "icon_foreground.png"), optimize=True)
        _camada(silhueta, adaptativo).save(os.path.join(pasta, "icon_monochrome.png"), optimize=True)
        print(f"{dpi}: legado {legado}px, adaptativo {adaptativo}px")

    # Copia sem densidade, para o launcher que nao casar com nenhuma acima.
    pasta = os.path.join(SAIDA, "mipmap")
    os.makedirs(pasta, exist_ok=True)
    arte.resize((192, 192), Image.LANCZOS).save(os.path.join(pasta, "icon.png"), optimize=True)
    Image.new("RGBA", (432, 432), FUNDO).save(os.path.join(pasta, "icon_background.png"), optimize=True)
    _camada(arte, 432).save(os.path.join(pasta, "icon_foreground.png"), optimize=True)
    _camada(silhueta, 432).save(os.path.join(pasta, "icon_monochrome.png"), optimize=True)
    print(f"escrito em {SAIDA}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
