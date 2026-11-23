"""Monta o logo e o gatinho que mexe o rabo do menu (ADR 0031).

    python tools/arte/montar_logo_e_vinhas.py

Entrada, em tools/arte/originais/menu/ (arte da equipe):
  * logo_crypto_cats.png: o nome do jogo com vinhas e flores, cada pixel de arte
    ampliado 30x, fundo transparente;
  * gato_siames_rabo/1.png a 4.png: o siames deitado abanando o rabo, 40x40
    cada, pixel de arte em tamanho real, fundo transparente (ADR 0039). A ida e
    volta e montada no jogo (menu_principal.gd);
  * gato_rabo.gif: o gato amarelo que ficava no menu ate o ADR 0039. Fica aqui
    como referencia; main() nao o monta mais.

Saida, em recursos/arte/:
  * logo_crypto_cats.png: o logo reduzido ao pixel de arte, recortado e
    ampliado 2x (2 pixels da tela base por pixel de arte, como o wallpaper).
    As letras, pretas no original, saem brancas, como o resto do texto do menu
    (ADR 0032);
  * gato_siames_rabo.png: os 4 quadros lado a lado, todos recortados pelo mesmo
    retangulo (o menor que cabe o gato nos quatro), para o corpo nao tremer;

A moldura de vinhas, que ate o ADR 0033 era gerada aqui como PNG para o cartao
do menu, agora e desenhada pelo proprio jogo, para qualquer tamanho de cartao
(scripts/visual/moldura_de_vinhas.gd, ADR 0034). As funcoes dela ficaram neste
arquivo como referencia do desenho original, mas main() nao as chama mais.

Requer: pip install pillow numpy
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
ORIGINAIS = RAIZ / "tools/arte/originais/menu"
ARTE = RAIZ / "recursos/arte"

AMPLIACAO_DO_LOGO = 30      # cada pixel de arte do logo original e um bloco 30x30
ESCALA = 2                  # pixels da tela base (640x360) por pixel de arte
CARTAO = (150, 156)         # cartao do menu em pixels de arte (300x312 na tela base)
RAIO = 7                    # raio dos cantos do cartao (14 px na tela base)
SOBRA = 6                   # quanto a moldura passa para fora do cartao, de cada lado

# Letras do logo: brancas no jogo (no desenho original sao pretas).
COR_DAS_LETRAS = (255, 255, 255)

# Cores tiradas do logo.
VINHA = (79, 137, 65)
FOLHA_ESCURA = (115, 164, 41)
FOLHA_CLARA = (139, 181, 24)
VERMELHO = (212, 70, 83)
ROSA = (229, 113, 124)
AMARELO = (246, 200, 48)
AZUL = (113, 193, 235)
AZUL_CLARO = (162, 219, 249)
LARANJA = (251, 203, 119)

# As duas flores do logo, como aparecem nele (centro em (1, 1)).
FLOR_VERMELHA = [
    ".p.",
    "ryr",
    ".r.",
]
FLOR_VERMELHA_DEITADA = [
    ".r.",
    "pyr",
    ".r.",
]
FLOR_AZUL = [
    ".bB",
    "BoB",
    "Bb.",
]
CORES = {"r": VERMELHO, "p": ROSA, "y": AMARELO, "b": AZUL, "B": AZUL_CLARO, "o": LARANJA}


def montar_logo() -> None:
    original = np.array(Image.open(ORIGINAIS / "logo_crypto_cats.png").convert("RGBA"))
    meio = AMPLIACAO_DO_LOGO // 2
    arte = original[meio::AMPLIACAO_DO_LOGO, meio::AMPLIACAO_DO_LOGO].copy()
    # Uns poucos pixels da borda vieram semitransparentes do programa de desenho.
    arte[..., 3] = np.where(arte[..., 3] >= 128, 255, 0)
    letras = (arte[..., :3] == 0).all(-1) & (arte[..., 3] > 0)
    arte[letras, :3] = COR_DAS_LETRAS
    ys, xs = np.where(arte[..., 3] > 0)
    arte = arte[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    imagem = Image.fromarray(arte, "RGBA")
    imagem = imagem.resize((imagem.width * ESCALA, imagem.height * ESCALA), Image.NEAREST)
    imagem.save(ARTE / "logo_crypto_cats.png")
    print(f"gerado: recursos/arte/logo_crypto_cats.png ({imagem.width}x{imagem.height})")


def montar_gato_siames_rabo() -> None:
    quadros = [Image.open(ORIGINAIS / "gato_siames_rabo" / f"{indice}.png").convert("RGBA") for indice in range(1, 5)]
    caixas = [quadro.getbbox() for quadro in quadros]
    caixa = (
        min(c[0] for c in caixas), min(c[1] for c in caixas),
        max(c[2] for c in caixas), max(c[3] for c in caixas),
    )
    recortes = [np.array(quadro.crop(caixa)) for quadro in quadros]
    folha = np.concatenate(recortes, axis=1)
    Image.fromarray(folha, "RGBA").save(ARTE / "gato_siames_rabo.png")
    print(f"gerado: recursos/arte/gato_siames_rabo.png ({folha.shape[1]}x{folha.shape[0]}, 4 quadros)")


def perimetro(s: float) -> tuple:
    """Ponto e normal para fora no contorno do cartao, pelo comprimento de arco s."""
    largura, altura = CARTAO
    retas = (largura - 2 * RAIO, altura - 2 * RAIO)
    arco = math.pi * RAIO / 2
    trechos = [retas[0], arco, retas[1], arco, retas[0], arco, retas[1], arco]
    s %= sum(trechos)
    cantos = [(largura - RAIO, RAIO), (largura - RAIO, altura - RAIO), (RAIO, altura - RAIO), (RAIO, RAIO)]
    for indice, comprimento in enumerate(trechos):
        if s <= comprimento:
            break
        s -= comprimento
    lado = indice // 2
    if indice % 2 == 0:  # reta: topo, direita, base, esquerda (sentido horario)
        if lado == 0:
            return (RAIO + s, 0.0), (0.0, -1.0)
        if lado == 1:
            return (largura, RAIO + s), (1.0, 0.0)
        if lado == 2:
            return (largura - RAIO - s, altura), (0.0, 1.0)
        return (0.0, altura - RAIO - s), (-1.0, 0.0)
    angulo = -math.pi / 2 + lado * math.pi / 2 + s / RAIO
    cx, cy = cantos[lado]
    normal = (math.cos(angulo), math.sin(angulo))
    return (cx + RAIO * normal[0], cy + RAIO * normal[1]), normal


def comprimento_total() -> float:
    largura, altura = CARTAO
    return 2 * (largura - 2 * RAIO) + 2 * (altura - 2 * RAIO) + 2 * math.pi * RAIO


def montar_moldura() -> None:
    sorteio = random.Random(31)
    largura = CARTAO[0] + 2 * SOBRA
    altura = CARTAO[1] + 2 * SOBRA
    tela = np.zeros((altura, largura, 4), dtype=np.uint8)

    def pintar(x: float, y: float, cor: tuple) -> None:
        px, py = int(round(x)) + SOBRA, int(round(y)) + SOBRA
        if 0 <= px < largura and 0 <= py < altura:
            tela[py, px] = (*cor, 255)

    total = comprimento_total()
    # Onda da vinha: periodo que fecha a volta inteira, para nao haver emenda.
    voltas = round(total / 14)
    def onda(s: float) -> float:
        return 1.2 * math.sin(2 * math.pi * voltas * s / total) + 0.4 * math.sin(2 * math.pi * 3 * voltas * s / total + 1.0)

    def ponto(s: float, afastamento: float = 0.0) -> tuple:
        (x, y), (nx, ny) = perimetro(s)
        d = onda(s) + afastamento
        return x + nx * d, y + ny * d

    # 1) a vinha: uma linha fina de um pixel, que sobe e desce como as do logo
    passo = 0.2
    s = 0.0
    while s < total:
        x, y = ponto(s)
        pintar(x, y, VINHA)
        s += passo

    # 2) gavinhas: raminhos curtos que saem da vinha em diagonal, como os do
    #    logo, terminando numa folha clara
    s = 6.0
    lado = 1
    while s < total - 4:
        for passo_da_gavinha in range(1, 4):
            x, y = ponto(s + passo_da_gavinha * 0.9, (1.0 + passo_da_gavinha) * lado)
            pintar(x, y, VINHA if passo_da_gavinha < 3 else FOLHA_CLARA)
        lado = -lado
        s += sorteio.uniform(11.0, 17.0)

    # 3) folhas: brotos de um ou dois pixels, alternando para dentro e para fora
    s = 1.0
    lado = 1
    while s < total:
        cor = FOLHA_CLARA if sorteio.random() < 0.55 else FOLHA_ESCURA
        x, y = ponto(s + 0.6, 1.4 * lado)
        pintar(x, y, cor)
        if sorteio.random() < 0.6:
            x, y = ponto(s + 1.5, 2.3 * lado)
            pintar(x, y, cor)
        lado = -lado
        s += sorteio.uniform(2.2, 3.6)

    # 4) flores: um cacho em cada canto e outras espalhadas pelas laterais
    def carimbo(s: float, desenho: list, afastamento: float) -> None:
        cx, cy = ponto(s, afastamento)
        cx, cy = int(round(cx)), int(round(cy))
        for dy, linha in enumerate(desenho):
            for dx, letra in enumerate(linha):
                if letra != ".":
                    pintar(cx + dx - 1, cy + dy - 1, CORES[letra])

    retas = (CARTAO[0] - 2 * RAIO, CARTAO[1] - 2 * RAIO)
    arco = math.pi * RAIO / 2
    inicio_dos_cantos = [retas[0], retas[0] + arco + retas[1], 2 * retas[0] + 2 * arco + retas[1],
                         2 * retas[0] + 3 * arco + 2 * retas[1]]
    flores = [FLOR_VERMELHA, FLOR_AZUL, FLOR_VERMELHA_DEITADA, FLOR_AZUL]
    for numero, inicio in enumerate(inicio_dos_cantos):
        meio = inicio + arco / 2
        carimbo(meio, FLOR_VERMELHA if numero % 2 == 0 else FLOR_VERMELHA_DEITADA, 1.0)
        carimbo(meio - 6.0, FLOR_AZUL, -1.0)
        carimbo(meio + 6.0, FLOR_VERMELHA_DEITADA if numero % 2 == 0 else FLOR_AZUL, 2.0)
    # Pelas laterais, uma flor a cada ~22 pixels, fora dos cantos, alternando cores
    # e o lado da vinha (dentro/fora), como no logo.
    vez = 0
    for numero, inicio in enumerate([0.0] + [c + arco for c in inicio_dos_cantos[:3]]):
        comprimento = retas[numero % 2]
        quantas = max(1, round(comprimento / 22) - 1)
        for k in range(1, quantas + 1):
            pos = inicio + comprimento * k / (quantas + 1) + sorteio.uniform(-2.0, 2.0)
            carimbo(pos, flores[vez % len(flores)], 1.5 if vez % 2 == 0 else -1.0)
            vez += 1

    imagem = Image.fromarray(tela, "RGBA")
    imagem = imagem.resize((largura * ESCALA, altura * ESCALA), Image.NEAREST)
    imagem.save(ARTE / "moldura_vinhas.png")
    print(f"gerado: recursos/arte/moldura_vinhas.png ({imagem.width}x{imagem.height})")


def main() -> None:
    montar_logo()
    montar_gato_siames_rabo()


if __name__ == "__main__":
    main()
