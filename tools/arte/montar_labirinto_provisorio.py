"""Monta a arte PROVISORIA do labirinto: grama e arbustos (ADR 0025).

    python tools/arte/montar_labirinto_provisorio.py

Entrada, em tools/arte/originais/labirinto_provisorio/:
  * grama.jpg: grama em pixel art, 64x64 pixels de arte ampliados 11,5x;
  * arbustos.jpg: pranchas de cerca viva vistas em 3/4, ampliadas ~3,66x, sobre
    o xadrez cinza de "transparente" (que no JPEG virou pixel de verdade).

Saida:
  * recursos/arte/grama.png (64x64): chao, repetido em ladrilho sob o mapa.
    A imagem ja emenda nos quatro lados.
  * recursos/arte/arbusto_pecas.png (32x40): 20 pecas de 8x8 para montar a
    parede celula a celula, em quartos (ver cenas/base/arbustos_do_labirinto.gd).
    Linha = tipo de peca, coluna = quarto da celula:

        colunas:  0 cima-esq   1 cima-dir   2 baixo-esq   3 baixo-dir
        linha 0   quina de fora (sem vizinho nem na horizontal nem na vertical)
        linha 1   borda horizontal (vizinho so na horizontal: cima ou baixo livre)
        linha 2   borda vertical (vizinho so na vertical: esquerda ou direita livre)
        linha 3   quina de dentro (vizinhos nos dois lados, diagonal livre)
        linha 4   miolo (cercado de arbusto)

    As pecas saem do primeiro arbusto da prancha (o anel de cima, a esquerda):
    as bordas de fora do anel dao as quinas e bordas, e os cantos do buraco do
    meio dao as quinas de dentro.

Por que pecas de 8x8 e nao um tile de 16x16 por formato: a parede do labirinto
gerado tem qualquer formato (T, cruz, ponta, curva). Com quartos, 20 pecas
cobrem todas as combinacoes de vizinhos, que como tiles inteiros seriam 47.

Requer: pip install pillow numpy scipy
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

RAIZ = Path(__file__).resolve().parents[2]
ORIGINAIS = RAIZ / "tools/arte/originais/labirinto_provisorio"

# Grade de pixel de arte de cada prancha: (tamanho do bloco, deslocamento x, y),
# achada procurando o bloco em que as cores ficam mais uniformes.
GRADE_GRAMA = (11.5, 0.0, 0.0)
GRADE_ARBUSTOS = (3.66, 1.5, 1.5)
DISTANCIA_DE_COR = 40

# Anel de arbusto de onde saem as pecas (em pixels de arte da prancha reduzida).
CAIXA_DO_ANEL = (14, 4, 76, 85)       # x0, y0, x1, y1 (exclusivo)
BURACO_DO_ANEL = (27, 35, 63, 52)     # x0, y0, x1, y1 (exclusivo)
MEIO_X = 44                           # coluna longe das quinas
MEIO_Y = 44                           # linha longe das quinas
LINHA_DA_COPA = 8                     # miolo: topo claro da copa
PECA = 8


def amostrar(caminho: Path, grade: tuple) -> np.ndarray:
    passo, ox, oy = grade
    imagem = np.array(Image.open(caminho).convert("RGB")).astype(float)
    linhas = int((imagem.shape[0] - oy) // passo)
    colunas = int((imagem.shape[1] - ox) // passo)
    raio = max(1, int(passo * 0.25))
    pixels = np.zeros((linhas, colunas, 3))
    for j in range(linhas):
        for i in range(colunas):
            cy, cx = int(oy + (j + 0.5) * passo), int(ox + (i + 0.5) * passo)
            bloco = imagem[cy - raio:cy + raio + 1, cx - raio:cx + raio + 1]
            pixels[j, i] = np.median(bloco.reshape(-1, 3), 0)
    return pixels


def paleta(cores: np.ndarray) -> np.ndarray:
    """Agrupa as cores borradas do JPEG e devolve cada uma trocada pela do grupo."""
    grupos: list = []
    for cor in cores:
        if not any(np.abs(cor - g).sum() < DISTANCIA_DE_COR for g in grupos):
            grupos.append(cor)
    grupos = np.array(grupos)
    for _ in range(12):
        qual = ((cores[:, None] - grupos[None]) ** 2).sum(-1).argmin(1)
        grupos = np.array([cores[qual == i].mean(0) if (qual == i).any() else grupos[i]
                           for i in range(len(grupos))])
    return grupos.round().clip(0, 255).astype(np.uint8)[qual]


def montar_grama() -> None:
    pixels = amostrar(ORIGINAIS / "grama.jpg", GRADE_GRAMA)
    limpo = paleta(pixels.reshape(-1, 3)).reshape(pixels.shape)
    Image.fromarray(limpo, "RGB").save(RAIZ / "recursos/arte/grama.png")
    print(f"gerado: recursos/arte/grama.png ({limpo.shape[1]}x{limpo.shape[0]})")


def limpar_arbustos() -> np.ndarray:
    pixels = amostrar(ORIGINAIS / "arbustos.jpg", GRADE_ARBUSTOS)
    maior, menor = pixels.max(-1), pixels.min(-1)
    xadrez = (maior - menor < 22) & (maior > 150)   # cinza claro sem cor: o "transparente"
    rgba = np.zeros(pixels.shape[:2] + (4,), np.uint8)
    rgba[~xadrez, :3] = paleta(pixels[~xadrez])
    rgba[~xadrez, 3] = 255
    # Ponto solto (sem vizinho opaco) e sobra do xadrez: apaga.
    opaco = rgba[..., 3] > 0
    vizinhos = ndimage.convolve(opaco.astype(int), np.ones((3, 3), int), mode="constant") - opaco
    rgba[opaco & (vizinhos == 0)] = 0
    return rgba


def montar_pecas(arbustos: np.ndarray) -> None:
    x0, y0, x1, y1 = CAIXA_DO_ANEL
    bx0, by0, bx1, by1 = BURACO_DO_ANEL
    # [linha][coluna] -> canto superior esquerdo da peca na prancha
    origens = [
        [(x0, y0), (x1 - PECA, y0), (x0, y1 - PECA), (x1 - PECA, y1 - PECA)],
        [(MEIO_X - PECA, y0), (MEIO_X, y0), (MEIO_X - PECA, y1 - PECA), (MEIO_X, y1 - PECA)],
        [(x0, MEIO_Y - PECA), (x1 - PECA, MEIO_Y - PECA), (x0, MEIO_Y), (x1 - PECA, MEIO_Y)],
        # Quina de dentro: o canto do buraco oposto ao quarto, entrando 3 px
        # nele, para o "dente" de grama aparecer no canto certo da peca.
        [(bx1 - 3, by1 - 3), (bx0 - 5, by1 - 3), (bx1 - 3, by0 - 5), (bx0 - 5, by0 - 5)],
        [(MEIO_X - PECA, LINHA_DA_COPA), (MEIO_X, LINHA_DA_COPA),
         (MEIO_X - PECA, LINHA_DA_COPA), (MEIO_X, LINHA_DA_COPA)],
    ]
    folha = np.zeros((PECA * len(origens), PECA * 4, 4), np.uint8)
    for linha, pecas in enumerate(origens):
        for coluna, (x, y) in enumerate(pecas):
            folha[linha * PECA:(linha + 1) * PECA, coluna * PECA:(coluna + 1) * PECA] = \
                arbustos[y:y + PECA, x:x + PECA]
    Image.fromarray(folha, "RGBA").save(RAIZ / "recursos/arte/arbusto_pecas.png")
    print(f"gerado: recursos/arte/arbusto_pecas.png ({folha.shape[1]}x{folha.shape[0]})")


if __name__ == "__main__":
    montar_grama()
    montar_pecas(limpar_arbustos())
