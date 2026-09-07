#!/usr/bin/env python3
"""Gera as telas de abertura: o splash do Android 12 e o boot splash da engine.

Por que existe: o pacote nao passa pelo exportador do Godot (os scripts fazem
`--export-pack` e chamam o gradle direto), e e o exportador quem gravaria
`res/drawable/splash_icon.webp` no modelo de compilacao. Sem ele o Android 12+
abre o jogo com o robo do Godot que vem dentro do godot-lib.aar. E sem
`application/boot_splash/image` no project.godot a engine desenha o proprio
logo logo em seguida: era o robo duas vezes antes do menu.

Saidas (versionadas; android/icons/install.sh copia as do drawable/):

  android/icons/drawable/splash_icon.webp            432 px, a arte dentro do circulo do sistema
  android/icons/drawable/splash_branding_image.webp  800x320 (2,5:1), a marca da Rica Solucoes
  shared/assets/splash/boot_splash.png               1080x1920, o que a engine mostra ate o menu

O Android nao mostra o icone inteiro: mascara os 2/3 centrais num circulo (192
dp de 288 dp). Por isso a escala da arte aqui **e medida**, nao herdada do
icone do launcher -- o 78% de la, que so precisa caber na zona segura
quadrada, faria o circulo comer a borda da mesa e as faiscas. A conta le o
raio do que brilha sobre o azul-marinho e encolhe a arte ate esse raio caber
no circulo, com folga.

A imagem de marca ocupa uma vista de 200x80 dp de tamanho fixo, e a imagem e
esticada nela: fora do 2,5:1 sai deformada.

O boot splash repete a mesma composicao (fundo, arte, marca) para a troca do
splash do sistema para o da engine nao dar salto.

Uso: venv/bin/python tools/make_splash.py
"""
from __future__ import annotations

import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_launcher_icons import FUNDO, _arte_recortada  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTE = os.path.join(RAIZ, "icon.png")
MARCA = os.path.join(RAIZ, "android", "icons", "brand", "rica_solucoes.png")
DRAWABLE = os.path.join(RAIZ, "android", "icons", "drawable")
BOOT = os.path.join(RAIZ, "shared", "assets", "splash", "boot_splash.png")

# O mesmo canvas do icone adaptativo xxxhdpi: e o que o exportador copiaria.
LADO_ICONE = 432
# O sistema mostra os 2/3 centrais, mascarados num circulo.
FRACAO_VISIVEL = 2.0 / 3.0
# Quanto do raio do circulo a arte pode ocupar. O resto e a folga que impede a
# faisca de encostar na borda mascarada.
OCUPACAO = 0.94
# Pixel que conta como arte: soma dos canais acima disto se destaca do
# azul-marinho (11+18+41 = 70) mesmo nas faiscas mais fracas.
LIMIAR_ARTE = 260
# Fracao do lado da arte que a borda leva para dissolver no fundo. A moldura
# arredondada do icone e um azul-marinho de vinheta, cinco niveis mais escuro
# que o fundo do tema: pouco para ser um desenho, o bastante para virar um
# quadrado fantasma dentro do circulo. Aqui ela sai desmanchando.
DESMANCHE = 0.05

# 200x80 dp em xxxhdpi.
MARCA_CANVAS = (800, 320)
MARCA_OCUPA = 0.80

# Num telefone de 1080 px de largura (xxhdpi, 3x): 192 dp de circulo, 200 dp
# de marca, 50 dp de margem.
BOOT_TAMANHO = (1080, 1920)
BOOT_CIRCULO = 576
BOOT_MARCA_LARGURA = 600
BOOT_MARCA_MARGEM = 150


def _raio_da_arte(arte: Image.Image) -> tuple[float, float, float]:
    """Centro e raio do que brilha sobre o fundo, em pixels da arte.

    E o que precisa sobreviver ao circulo: cartas, dado, mesa e faiscas. O
    azul-marinho em volta pode ser cortado a vontade, porque a tela por tras
    tem exatamente a mesma cor.
    """
    largura, altura = arte.size
    px = arte.load()
    pontos = []
    for y in range(altura):
        for x in range(largura):
            r, g, b, a = px[x, y]
            if a > 200 and r + g + b > LIMIAR_ARTE:
                pontos.append((x, y))
    if not pontos:
        raise SystemExit("icon.png nao tem arte legivel sobre o fundo")
    xs = [p[0] for p in pontos]
    ys = [p[1] for p in pontos]
    cx = (min(xs) + max(xs)) / 2.0
    cy = (min(ys) + max(ys)) / 2.0
    raio = max(math.hypot(x - cx, y - cy) for x, y in pontos)
    return cx, cy, raio


def _desmanchada(arte: Image.Image) -> Image.Image:
    """A mesma arte com a borda da moldura virando transparencia aos poucos."""
    borda = max(2, int(round(arte.size[0] * DESMANCHE)))
    alfa = arte.getchannel("A")
    # Encolhe primeiro: borrar sozinho espalharia a borda para FORA da moldura
    # e deixaria um halo, em vez de puxa-la para dentro.
    alfa = alfa.filter(ImageFilter.MinFilter(borda | 1))
    alfa = alfa.filter(ImageFilter.GaussianBlur(borda * 0.6))
    saida = arte.copy()
    saida.putalpha(alfa)
    return saida


def _camada_do_circulo(arte: Image.Image, lado: int) -> Image.Image:
    """A arte num canvas transparente, na escala em que cabe no circulo."""
    cx, cy, raio = _raio_da_arte(arte)
    raio_circulo = lado * FRACAO_VISIVEL / 2.0
    escala = (raio_circulo * OCUPACAO) / raio
    alvo = max(1, int(round(arte.size[0] * escala)))
    menor = _desmanchada(arte.resize((alvo, alvo), Image.LANCZOS))
    # Centra pelo centro da ARTE, nao pelo do canvas: a mesa fica na metade de
    # baixo do icone e centrar pelo canvas jogaria o dado para fora do circulo.
    canvas = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    canvas.alpha_composite(menor, (int(round(lado / 2.0 - cx * escala)),
                                   int(round(lado / 2.0 - cy * escala))))
    print(f"arte: raio {raio:.0f}px de {arte.size[0]} -> {alvo}px no canvas de {lado} "
          f"(circulo de {2 * raio_circulo:.0f}px)")
    return canvas


def _marca(canvas: tuple[int, int]) -> Image.Image:
    """A marca centrada num canvas transparente, em MARCA_OCUPA da largura."""
    logo = Image.open(MARCA).convert("RGBA")
    escala = min(canvas[0] * MARCA_OCUPA / logo.width, canvas[1] * 0.6 / logo.height)
    novo = logo.resize((round(logo.width * escala), round(logo.height * escala)), Image.LANCZOS)
    saida = Image.new("RGBA", canvas, (0, 0, 0, 0))
    saida.alpha_composite(novo, ((canvas[0] - novo.width) // 2, (canvas[1] - novo.height) // 2))
    return saida


def _como_o_sistema_mostra(camada: Image.Image, diametro: int) -> Image.Image:
    """Os 2/3 centrais mascarados no circulo: o recorte que o Android aplica."""
    lado = camada.size[0]
    d = int(round(lado * FRACAO_VISIVEL))
    x0 = (lado - d) // 2
    recorte = camada.crop((x0, x0, x0 + d, x0 + d))
    escala = 4
    grande = Image.new("L", (d * escala, d * escala), 0)
    ImageDraw.Draw(grande).ellipse((0, 0, d * escala - 1, d * escala - 1), fill=255)
    mascara = grande.resize((d, d), Image.LANCZOS)
    recorte.putalpha(ImageChops.multiply(recorte.getchannel("A"), mascara))
    return recorte.resize((diametro, diametro), Image.LANCZOS)


def main() -> int:
    for caminho, nome in ((FONTE, "icon.png"), (MARCA, "a marca da Rica Solucoes")):
        if not os.path.exists(caminho):
            print(f"{nome} nao encontrado em {caminho}", file=sys.stderr)
            return 1
    fonte = Image.open(FONTE).convert("RGBA")
    if fonte.size[0] != fonte.size[1]:
        print("icon.png precisa ser quadrado", file=sys.stderr)
        return 1

    camada = _camada_do_circulo(_arte_recortada(fonte), LADO_ICONE)
    marca = _marca(MARCA_CANVAS)

    os.makedirs(DRAWABLE, exist_ok=True)
    camada.save(os.path.join(DRAWABLE, "splash_icon.webp"), lossless=True)
    marca.save(os.path.join(DRAWABLE, "splash_branding_image.webp"), lossless=True)
    print(f"drawable: splash_icon {LADO_ICONE}px, "
          f"splash_branding_image {MARCA_CANVAS[0]}x{MARCA_CANVAS[1]}")

    largura, altura = BOOT_TAMANHO
    boot = Image.new("RGBA", BOOT_TAMANHO, FUNDO)
    circulo = _como_o_sistema_mostra(camada, BOOT_CIRCULO)
    boot.alpha_composite(circulo, ((largura - BOOT_CIRCULO) // 2, (altura - BOOT_CIRCULO) // 2))
    marca_boot = marca.resize((BOOT_MARCA_LARGURA, BOOT_MARCA_LARGURA * MARCA_CANVAS[1] // MARCA_CANVAS[0]),
                              Image.LANCZOS)
    boot.alpha_composite(marca_boot, ((largura - marca_boot.size[0]) // 2,
                                      altura - BOOT_MARCA_MARGEM - marca_boot.size[1]))
    os.makedirs(os.path.dirname(BOOT), exist_ok=True)
    # Sem alpha: a engine desenha a imagem sobre boot_splash/bg_color, que e o
    # mesmo azul-marinho, e o PNG RGB e menor dentro do pacote.
    boot.convert("RGB").save(BOOT, optimize=True)
    print(f"boot splash: {largura}x{altura} em {os.path.relpath(BOOT, RAIZ)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
