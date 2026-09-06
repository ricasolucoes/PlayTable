#!/usr/bin/env python3
"""Gera as telas de abertura: o splash do Android 12 e o boot splash da engine.

Por que existe: o pacote nao passa pelo exportador do Godot (os scripts fazem
`--export-pack` e chamam o gradle direto), e e o exportador quem gravaria
`res/drawable/splash_icon.webp` no modelo de compilacao. Sem ele o Android 12+
abre o jogo com o robo do Godot que vem dentro do godot-lib.aar. E sem
`application/boot_splash/image` no project.godot a engine desenha o proprio logo
logo em seguida: era o robo duas vezes antes do menu.

Saidas (versionadas; android/icons/install.sh copia as do drawable/):

  android/icons/drawable/splash_icon.webp            432 px, a camada da arte do icone adaptativo
  android/icons/drawable/splash_branding_image.webp  800x320 (2,5:1), o logo da Rica Solucoes
  shared/assets/splash/boot_splash.png               1080x1920, o que a engine mostra ate o menu

O Android mascara o icone do splash num circulo com 2/3 do lado (192 dp dentro
de 288 dp) e estica a imagem de marca em exatamente 200x80 dp -- dai o 2,5:1.
O boot splash repete a mesma composicao (fundo, circulo, marca) para a troca de
um para o outro nao dar salto.

Uso: venv/bin/python tools/make_splash.py
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_launcher_icons import FUNDO, _arte_recortada, _camada  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTE = os.path.join(RAIZ, "icon.png")
MARCA = os.path.join(RAIZ, "android", "icons", "brand", "rica_solucoes_light.png")
DRAWABLE = os.path.join(RAIZ, "android", "icons", "drawable")
BOOT = os.path.join(RAIZ, "shared", "assets", "splash", "boot_splash.png")

# O mesmo canvas do icone adaptativo xxxhdpi: e o que o exportador copiaria.
LADO_ICONE = 432
# 200x80 dp em xxxhdpi. A vista de marca tem esse tamanho fixo e a imagem e
# esticada nele: outra proporcao sai deformada.
MARCA_CANVAS = (800, 320)
MARCA_OCUPA = 0.80

# Num telefone de 1080 px (xxhdpi, 3x): 192 dp de circulo, 200 dp de marca.
BOOT_TAMANHO = (1080, 1920)
BOOT_CIRCULO = 576
BOOT_MARCA_LARGURA = 600
BOOT_MARCA_MARGEM = 150


def _marca(canvas: tuple[int, int]) -> Image.Image:
    """O logo centrado num canvas transparente, ocupando MARCA_OCUPA da largura."""
    logo = Image.open(MARCA).convert("RGBA")
    escala = min(canvas[0] * MARCA_OCUPA / logo.width, canvas[1] * 0.6 / logo.height)
    novo = logo.resize((round(logo.width * escala), round(logo.height * escala)), Image.LANCZOS)
    saida = Image.new("RGBA", canvas, (0, 0, 0, 0))
    saida.alpha_composite(novo, ((canvas[0] - novo.width) // 2, (canvas[1] - novo.height) // 2))
    return saida


def _circulo(camada: Image.Image, diametro: int) -> Image.Image:
    """Os 2/3 centrais da camada, mascarados num circulo: o que o Android mostra."""
    lado = camada.size[0]
    d = lado * 2 // 3
    x0 = (lado - d) // 2
    recorte = camada.crop((x0, x0, x0 + d, x0 + d))
    escala = 4
    grande = Image.new("L", (d * escala, d * escala), 0)
    ImageDraw.Draw(grande).ellipse((0, 0, d * escala - 1, d * escala - 1), fill=255)
    mascara = grande.resize((d, d), Image.LANCZOS)
    recorte.putalpha(ImageChops.multiply(recorte.getchannel("A"), mascara))
    return recorte.resize((diametro, diametro), Image.LANCZOS)


def main() -> int:
    for caminho, nome in ((FONTE, "icon.png"), (MARCA, "o logo da Rica Solucoes")):
        if not os.path.exists(caminho):
            print(f"{nome} nao encontrado em {caminho}", file=sys.stderr)
            return 1
    fonte = Image.open(FONTE).convert("RGBA")
    if fonte.size[0] != fonte.size[1]:
        print("icon.png precisa ser quadrado", file=sys.stderr)
        return 1

    camada = _camada(_arte_recortada(fonte), LADO_ICONE)
    marca = _marca(MARCA_CANVAS)

    os.makedirs(DRAWABLE, exist_ok=True)
    camada.save(os.path.join(DRAWABLE, "splash_icon.webp"), lossless=True)
    marca.save(os.path.join(DRAWABLE, "splash_branding_image.webp"), lossless=True)
    print(f"drawable: splash_icon {LADO_ICONE}px, splash_branding_image {MARCA_CANVAS[0]}x{MARCA_CANVAS[1]}")

    largura, altura = BOOT_TAMANHO
    boot = Image.new("RGBA", BOOT_TAMANHO, FUNDO)
    circulo = _circulo(camada, BOOT_CIRCULO)
    boot.alpha_composite(circulo, ((largura - BOOT_CIRCULO) // 2, (altura - BOOT_CIRCULO) // 2))
    marca_boot = marca.resize((BOOT_MARCA_LARGURA, BOOT_MARCA_LARGURA * 2 // 5), Image.LANCZOS)
    boot.alpha_composite(marca_boot, ((largura - marca_boot.size[0]) // 2,
                                      altura - BOOT_MARCA_MARGEM - marca_boot.size[1]))
    os.makedirs(os.path.dirname(BOOT), exist_ok=True)
    # Sem alpha: a engine desenha a imagem inteira sobre boot_splash/bg_color,
    # que e o mesmo azul-marinho, e o PNG RGB e menor dentro do pacote.
    boot.convert("RGB").save(BOOT, optimize=True)
    print(f"boot splash: {largura}x{altura} em {os.path.relpath(BOOT, RAIZ)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
