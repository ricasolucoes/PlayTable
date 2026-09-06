#!/usr/bin/env python3
"""Gera os assets visuais do PlayTable pela API do Gemini.

O CLAUDE.md desta pasta exige que todo material visual novo venha do Gemini, com
proveniência ao lado do arquivo. Este script é o caminho único para isso.

Uso:
    set -a; source /Users/sierra/Dev/Jogos/.env; set +a
    venv/bin/python tools/gen_art.py campo_minado --dry-run
    venv/bin/python tools/gen_art.py campo_minado
    venv/bin/python tools/gen_art.py --all
    venv/bin/python tools/gen_art.py damas --asset peca_escura --force
    venv/bin/python tools/gen_art.py --list

O manifesto de cada jogo é `tools/art/<game_id>.json`: uma bíblia de estilo, que
entra em TODO prompt do mesmo jogo, e a lista de assets. Sem a bíblia repetida
cada sprite nasce de um desenho animado diferente.

Idempotência por hash: um asset está pronto quando existem o PNG e o
`.prompt.md`, e o `prompt_sha256` gravado bate com o do prompt atual. Editar a
bíblia invalida o lote inteiro sozinho; reexecutar sem editar nada não gasta
chamada nenhuma.
"""

import argparse
import hashlib
import io
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
MANIFESTOS = RAIZ / "tools" / "art"

MODELO_PADRAO = "gemini-3.1-flash-image"

# Fundo chroma pedido ao modelo. Verde puro porque nenhuma peça de tabuleiro é
# verde puro, e porque transparência pedida ao modelo costuma voltar cinza.
CHROMA = "#00FF00"

# Frações da imagem que a máscara de chroma pode ocupar. Fora disso o recorte
# não é confiável: acima, o modelo ignorou o objeto; abaixo, ignorou o fundo.
CHROMA_MIN = 0.05
CHROMA_MAX = 0.92

RODAPE_PROMPT = (
    "Fundo: cor sólida %s, absolutamente uniforme, sem gradiente e sem sombra "
    "projetada no fundo. Sem texto de qualquer espécie, sem marca d'água, sem "
    "interface, sem moldura, sem legenda. O objeto centrado, inteiro, sem corte "
    "nas bordas." % CHROMA
)


# --------------------------------------------------------------------- manifesto

def carregar_manifesto(game_id):
    caminho = MANIFESTOS / ("%s.json" % game_id)
    if not caminho.exists():
        raise SystemExit("manifesto não existe: %s" % caminho)
    return json.loads(caminho.read_text(encoding="utf-8"))


def jogos_disponiveis():
    return sorted(p.stem for p in MANIFESTOS.glob("*.json"))


def montar_prompt(man, asset):
    """A bíblia primeiro, o pedido depois, as proibições por último."""
    partes = [man["style_bible"].strip(), asset["prompt"].strip()]
    if asset.get("background", man.get("defaults", {}).get("background", "chroma")) == "chroma":
        partes.append(RODAPE_PROMPT)
    else:
        partes.append("Sem texto, sem marca d'água, sem interface.")
    return "\n\n".join(partes)


def modelo_de(man, asset):
    return asset.get("model") or man.get("defaults", {}).get("model") or MODELO_PADRAO


def assinatura(man, asset):
    """Hash do que de fato determina o pixel: bíblia, prompt, modelo, tamanho."""
    corpo = "\n".join([
        montar_prompt(man, asset),
        modelo_de(man, asset),
        str(asset.get("size", man.get("defaults", {}).get("size", 512))),
        str(asset.get("grid", "")),
        str(asset.get("crop_aspect", "")),
        ",".join(asset.get("reference", [])),
    ])
    return hashlib.sha256(corpo.encode("utf-8")).hexdigest()


# --------------------------------------------------------------- proveniência

def pasta_de(man, asset):
    """A pasta do asset: a do manifesto, ou a do proprio asset quando ele a declara.

    O Memoria le o verso em `shared/assets/cards/` e as gemas em
    `shared/assets/rewards/` -- caminhos que `AssetCatalog.get_card_back()` e
    `get_gem()` conhecem. Um manifesto, duas pastas.
    """
    return RAIZ / asset.get("out_dir", man["out_dir"])


def caminho_png(man, asset):
    return pasta_de(man, asset) / ("%s.png" % asset["name"])


def caminho_md(man, asset):
    return pasta_de(man, asset) / ("%s.prompt.md" % asset["name"])


def ler_hash_gravado(md):
    if not md.exists():
        return None
    for linha in md.read_text(encoding="utf-8").splitlines():
        # Aprovacao manual registra a spec do manifesto separadamente do
        # prompt efetivo da ferramenta image_gen, preservado no mesmo MD.
        if linha.startswith(("approved_manifest_sha256:", "prompt_sha256:")):
            return linha.split(":", 1)[1].strip()
    return None


def eh_decalque(man, asset):
    """Decalque = imagem lida como icone plano (algarismo, bandeira, navio, verso).

    Sai do manifesto: `"import": "decal"` no asset ou em `defaults`. Albedo de
    peca (damas, reversi, mancala) fica no padrao do Godot, com compressao de
    VRAM, que e o certo para textura que envolve uma malha.
    """
    return asset.get("import", man.get("defaults", {}).get("import", "")) == "decal"


def gravar_import(png, decalque):
    """Semeia o `.import` de um decalque antes de o Godot o inventar.

    O projeto reimporta textura 3D com compressao de VRAM (ASTC no Android), e
    isso borra a borda do algarismo e o contorno recortado do icone. Para o
    decalque o `.import` precisa nascer sem compressao (`compress/mode=0`), com
    `detect_3d/compress_to=0` para o Godot nao trocar por VRAM ao ver o uso em
    3D, mipmaps ligados e a borda alfa corrigida. Escrito so quando ainda nao
    existe: o Godot completa `uid` e caminhos na primeira importacao, e depois
    disso o arquivo e dele.
    """
    if not decalque:
        return
    imp = png.with_name(png.name + ".import")
    if imp.exists():
        return
    rel = "res://" + png.relative_to(RAIZ).as_posix()
    imp.write_text("\n".join([
        "[remap]",
        "",
        'importer="texture"',
        'type="CompressedTexture2D"',
        "metadata={",
        '"vram_texture": false',
        "}",
        "",
        "[deps]",
        "",
        'source_file="%s"' % rel,
        "",
        "[params]",
        "",
        "compress/mode=0",
        "compress/high_quality=false",
        "compress/lossy_quality=0.7",
        "compress/uastc_level=0",
        "compress/rdo_quality_loss=0.0",
        "compress/hdr_compression=1",
        "compress/normal_map=0",
        "compress/channel_pack=0",
        "mipmaps/generate=true",
        "mipmaps/limit=-1",
        "roughness/mode=0",
        'roughness/src_normal=""',
        "process/channel_remap/red=0",
        "process/channel_remap/green=1",
        "process/channel_remap/blue=2",
        "process/channel_remap/alpha=3",
        "process/fix_alpha_border=true",
        "process/premult_alpha=false",
        "process/normal_map_invert_y=false",
        "process/hdr_as_srgb=false",
        "process/hdr_clamp_exposure=false",
        "process/size_limit=0",
        "detect_3d/compress_to=0",
        "",
    ]), encoding="utf-8")


def gravar_proveniencia(man, asset, modelo, pos, extras):
    """Sem o .md ao lado ninguém consegue regenerar nem variar o asset."""
    md = caminho_md(man, asset)
    md.parent.mkdir(parents=True, exist_ok=True)
    corpo = [
        "---",
        "model: %s" % modelo,
        "date: %s" % datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
        "prompt_sha256: %s" % assinatura(man, asset),
        "background: %s" % asset.get("background", man.get("defaults", {}).get("background", "chroma")),
        "references: %s" % (", ".join(asset.get("reference", [])) or "-"),
        "post: %s" % pos,
        "---",
        "",
        "# %s / %s" % (man["game_id"], asset["name"]),
        "",
        "## Bíblia de estilo",
        "",
        man["style_bible"].strip(),
        "",
        "## Prompt",
        "",
        asset["prompt"].strip(),
        "",
    ]
    if extras:
        corpo += ["## Notas", "", extras, ""]
    md.write_text("\n".join(corpo), encoding="utf-8")


# ------------------------------------------------------------- pós-processo

def recortar_chroma(dados_png, lado):
    """Tira o fundo verde, mata o vazamento na borda e centra numa tela quadrada.

    Devolve (bytes_png, descricao) ou levanta ValueError quando a máscara é
    grande ou pequena demais para o recorte ser confiável -- e aí o asset não é
    gravado, porque um PNG com halo verde no jogo é pior que asset nenhum.
    """
    from PIL import Image
    import numpy as np

    img = Image.open(io.BytesIO(dados_png)).convert("RGBA")
    a = np.array(img).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]

    # Verde dominante sobre os outros dois canais. Comparar com #00FF00 exato
    # não funciona: o modelo devolve o fundo com ruído de compressão.
    mascara = (g > 110) & (g > r * 13 // 10) & (g > b * 13 // 10)
    fracao = float(mascara.mean())
    if fracao > CHROMA_MAX:
        raise ValueError("chroma cobriu %.0f%% da imagem: o modelo não desenhou o objeto" % (fracao * 100))
    if fracao < CHROMA_MIN:
        raise ValueError("chroma cobriu só %.0f%%: o modelo ignorou o fundo pedido" % (fracao * 100))

    a[..., 3] = np.where(mascara, 0, 255)

    # Despill: sem isto sobra um halo verde no contorno, que aparece como
    # auréola quando a peça anda sobre feltro escuro.
    visivel = ~mascara
    media = (r + b) // 2
    excesso = visivel & (g > media * 112 // 100)
    a[..., 1] = np.where(excesso, media * 112 // 100, g)

    fora = Image.fromarray(a.astype(np.uint8), "RGBA")

    # Erode 1 px no alfa: a borda do recorte fica meio transparente e meio verde.
    alfa = fora.getchannel("A")
    from PIL import ImageFilter
    alfa = alfa.filter(ImageFilter.MinFilter(3))
    fora.putalpha(alfa)

    caixa = fora.getbbox()
    if caixa:
        fora = fora.crop(caixa)

    # Centra numa tela quadrada, para toda peça do jogo ter a mesma âncora.
    lado_fonte = max(fora.size)
    tela = Image.new("RGBA", (lado_fonte, lado_fonte), (0, 0, 0, 0))
    tela.paste(fora, ((lado_fonte - fora.size[0]) // 2, (lado_fonte - fora.size[1]) // 2))
    tela = tela.resize((lado, lado), Image.LANCZOS)

    saida = io.BytesIO()
    tela.save(saida, "PNG", optimize=True)
    return saida.getvalue(), "chroma-key, despill, erode 1px, bbox, %dx%d LANCZOS" % (lado, lado)


def recortar_proporcao(dados_png, proporcao, altura):
    """Recorta o centro da imagem na proporção `"L:A"` e reamostra para `altura`.

    Para o que é esticado num retângulo pelo jogo -- o verso da carta do
    Memória, desenhado com `draw_texture_rect` no retângulo da carta. O modelo
    devolve quadrado; um quadrado com margem transparente (o caminho do chroma)
    viraria uma carta pequena dentro da carta, e um quadrado esticado a 5:8
    deforma qualquer padrão. Recortar o centro custa as bordas do desenho, e
    por isso o prompt pede padrão contínuo que tolere o corte.
    """
    from PIL import Image
    lw, la = (int(x) for x in proporcao.split(":"))
    img = Image.open(io.BytesIO(dados_png)).convert("RGBA")
    w, h = img.size
    alvo = lw / la
    if w / h > alvo:
        nw = int(round(h * alvo))
        caixa = ((w - nw) // 2, 0, (w - nw) // 2 + nw, h)
    else:
        nh = int(round(w / alvo))
        caixa = (0, (h - nh) // 2, w, (h - nh) // 2 + nh)
    fora = img.crop(caixa).resize((int(round(altura * alvo)), altura), Image.LANCZOS)
    saida = io.BytesIO()
    fora.save(saida, "PNG", optimize=True)
    return saida.getvalue(), "recorte central %s, %dx%d LANCZOS" % (proporcao, fora.size[0], fora.size[1])


def fatiar_grade(dados_png, cols, linhas, destino, nome):
    """Corta uma tira em células de tamanho igual.

    Aritmético e não por contorno: a geometria é conhecida, e achar contorno
    numa tira de dígitos é chute -- um '1' tem contorno muito menor que um '8'.
    """
    from PIL import Image
    img = Image.open(io.BytesIO(dados_png)).convert("RGBA")
    lc, ll = img.size[0] // cols, img.size[1] // linhas
    escritos = []
    for y in range(linhas):
        for x in range(cols):
            i = y * cols + x + 1
            celula = img.crop((x * lc, y * ll, (x + 1) * lc, (y + 1) * ll))
            p = destino / ("%s_%d.png" % (nome, i))
            celula.save(p, "PNG", optimize=True)
            escritos.append(p.name)
    return escritos


# ------------------------------------------------------------------- geração

def gerar_um(cliente, man, asset, tentativas):
    from google.genai import types

    modelo = modelo_de(man, asset)
    prompt = montar_prompt(man, asset)
    padroes = man.get("defaults", {})
    lado = int(asset.get("size", padroes.get("size", 512)))

    conteudo = [prompt]
    # Referências: a peça-mestra volta como imagem nas chamadas seguintes, que é
    # o que faz o elenco inteiro nascer do mesmo desenho.
    for ref in asset.get("reference", []):
        p = RAIZ / man["out_dir"] / ("%s.png" % ref)
        if p.exists():
            conteudo.append(types.Part.from_bytes(data=p.read_bytes(), mime_type="image/png"))

    ultimo = None
    for tentativa in range(1, tentativas + 1):
        try:
            resp = cliente.models.generate_content(model=modelo, contents=conteudo)
            for parte in resp.candidates[0].content.parts:
                if getattr(parte, "inline_data", None) and parte.inline_data.data:
                    return parte.inline_data.data, modelo
            raise RuntimeError("resposta sem imagem")
        except Exception as e:  # noqa: BLE001 - a API levanta tipos variados
            ultimo = e
            transitorio = any(c in str(e) for c in ("429", "500", "503", "RESOURCE_EXHAUSTED", "UNAVAILABLE"))
            if not transitorio or tentativa == tentativas:
                raise
            espera = 2 ** tentativa
            print("      ...%s; nova tentativa em %ds" % (type(e).__name__, espera))
            time.sleep(espera)
    raise ultimo


def processar(cliente, man, asset, forcar, tentativas):
    png = caminho_png(man, asset)
    md = caminho_md(man, asset)
    nome = asset["name"]

    if not forcar and png.exists() and md.exists() and ler_hash_gravado(md) == assinatura(man, asset):
        print("   = %-18s já pronto" % nome)
        return "pronto"

    print("   + %-18s gerando (%s)" % (nome, modelo_de(man, asset)))
    dados, modelo = gerar_um(cliente, man, asset, tentativas)

    padroes = man.get("defaults", {})
    fundo = asset.get("background", padroes.get("background", "chroma"))
    pos = "nenhum"
    if fundo == "chroma":
        lado = int(asset.get("size", padroes.get("size", 512)))
        dados, pos = recortar_chroma(dados, lado)
    elif asset.get("crop_aspect"):
        altura = int(asset.get("size", padroes.get("size", 512)))
        dados, pos = recortar_proporcao(dados, asset["crop_aspect"], altura)

    png.parent.mkdir(parents=True, exist_ok=True)
    # Grava em .tmp e só então renomeia: sem isso, uma falha no meio deixaria um
    # arquivo pela metade que a próxima execução leria como pronto.
    tmp = png.with_suffix(".png.tmp")
    tmp.write_bytes(dados)
    os.replace(tmp, png)
    gravar_import(png, eh_decalque(man, asset))

    extras = ""
    if asset.get("grid"):
        g = asset["grid"]
        fatias = fatiar_grade(dados, int(g["cols"]), int(g.get("rows", 1)), png.parent, nome)
        for fatia in fatias:
            gravar_import(png.parent / fatia, eh_decalque(man, asset))
        extras = "Fatiado em %d célula(s): %s" % (len(fatias), ", ".join(fatias))
        pos += "; grade %dx%d" % (int(g["cols"]), int(g.get("rows", 1)))


    gravar_proveniencia(man, asset, modelo, pos, extras)
    print("      %s (%.0f KB)" % (png.relative_to(RAIZ), png.stat().st_size / 1024))
    return "gerado"


# ---------------------------------------------------------------------- CLI

def listar(game_ids):
    for gid in game_ids:
        man = carregar_manifesto(gid)
        print("%s  (%s)" % (gid, man["out_dir"]))
        for asset in man["assets"]:
            png, md = caminho_png(man, asset), caminho_md(man, asset)
            if not png.exists():
                estado = "faltando"
            elif not md.exists():
                estado = "SEM PROVENIÊNCIA"
            elif ler_hash_gravado(md) != assinatura(man, asset):
                estado = "desatualizado (a bíblia ou o prompt mudaram)"
            else:
                estado = "ok, %.0f KB" % (png.stat().st_size / 1024)
            print("   %-20s %s" % (asset["name"], estado))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("game_id", nargs="?", help="jogo do manifesto (tools/art/<id>.json)")
    ap.add_argument("--all", action="store_true", help="todos os manifestos")
    ap.add_argument("--asset", action="append", default=[], help="só estes assets")
    ap.add_argument("--force", action="store_true", help="regera mesmo estando pronto")
    ap.add_argument("--dry-run", action="store_true", help="imprime o prompt montado e sai")
    ap.add_argument("--list", action="store_true", help="estado de cada asset")
    ap.add_argument("--retries", type=int, default=3)
    args = ap.parse_args()

    if args.all:
        alvos = jogos_disponiveis()
    elif args.game_id:
        alvos = [args.game_id]
    elif args.list:
        alvos = jogos_disponiveis()
    else:
        ap.error("informe um game_id, --all ou --list")

    if args.list:
        listar(alvos)
        return 0

    if args.dry_run:
        for gid in alvos:
            man = carregar_manifesto(gid)
            for asset in man["assets"]:
                if args.asset and asset["name"] not in args.asset:
                    continue
                print("=" * 72)
                print("%s / %s   [%s]" % (gid, asset["name"], modelo_de(man, asset)))
                print("=" * 72)
                print(montar_prompt(man, asset))
                print()
        return 0

    chave = os.environ.get("GEMINI_API_KEY", "").strip()
    if not chave:
        print("GEMINI_API_KEY não está no ambiente.", file=sys.stderr)
        print("  set -a; source /Users/sierra/Dev/Jogos/.env; set +a", file=sys.stderr)
        return 2

    from google import genai
    cliente = genai.Client()

    falhas = []
    for gid in alvos:
        man = carregar_manifesto(gid)
        print("== %s ==" % gid)
        # O herói primeiro: ele é a referência dos outros, e gerar fora de ordem
        # faria o resto nascer sem referência nenhuma.
        heroi = man.get("hero")
        ordem = sorted(man["assets"], key=lambda a: 0 if a["name"] == heroi else 1)
        for asset in ordem:
            if args.asset and asset["name"] not in args.asset:
                continue
            try:
                processar(cliente, man, asset, args.force, args.retries)
            except Exception as e:  # noqa: BLE001
                print("   ! %-18s %s: %s" % (asset["name"], type(e).__name__, str(e)[:150]))
                falhas.append("%s/%s" % (gid, asset["name"]))

    if falhas:
        print("\nfalharam %d: %s" % (len(falhas), ", ".join(falhas)))
        return 1
    print("\ntudo pronto.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
