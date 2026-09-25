"""Normaliza a folha original do cachorro para a grade do jogo (ADR 0013).

    python tools/arte/extrair_cachorro.py

Entrada: tools/arte/cachorro_original.webp (5 linhas x 4 quadros, fundo preto).
Diferente da folha do gato, esta foi reamostrada com escala fracionaria: nao ha
grade de pixel de arte para amostrar. Cada quadro e reduzido pela mesma escala
(ESCALA px de origem por pixel do jogo), com a cor tirada da mediana do miolo
de cada bloco e a paleta unificada no fim.

A folha original so tem frente, sentado e lateral virada para a ESQUERDA. A
saida segue a grade comum a gato e cachorro (tools/gerar_sprite_frames.gd):
  0 andar_baixo    <- frente (linha 3 da origem)
  1 andar_direita  <- lateral espelhada (linha 2 da origem)
  2 andar_cima     <- lateral (linha 4 da origem); sem vista de costas
  3 andar_esquerda <- lateral (linha 2 da origem)
  4 parado         <- sentado (linha 5 da origem)
Saida: recursos/arte/cachorro.png. Requer: pip install pillow numpy
"""
from pathlib import Path
from PIL import Image
import numpy as np

RAIZ = Path(__file__).resolve().parents[2]
F = 24
ESCALA = 7.3
LIMIAR_FUNDO = 60

im = np.array(Image.open(RAIZ / 'tools/arte/cachorro_original.webp').convert('RGB')).astype(float)
opaco = im.sum(2) > LIMIAR_FUNDO


def bandas(v, gap=12):
    idx = np.where(v)[0]; r = []; s = p = idx[0]
    for k in idx[1:]:
        if k - p > gap: r.append((s, p)); s = k
        p = k
    r.append((s, p))
    return [x for x in r if x[1] - x[0] > 20]   # descarta ruido de compressao


def reduzir(y0, y1, x0, x1):
    ys, xs = np.where(opaco[y0:y1 + 1, x0:x1 + 1])
    by0, by1, bx0, bx1 = ys.min() + y0, ys.max() + y0, xs.min() + x0, xs.max() + x0
    h = int(np.ceil((by1 - by0 + 1) / ESCALA)); w = int(np.ceil((bx1 - bx0 + 1) / ESCALA))
    assert h <= F - 1 and w <= F, (w, h)
    q = np.zeros((F, F, 4), np.uint8)
    oy = F - h - 1; ox = (F - w) // 2        # pes (sombra) na base do quadro
    for j in range(h):
        for i in range(w):
            ya, yb = int(by0 + j * ESCALA), int(by0 + (j + 1) * ESCALA)
            xa, xb = int(bx0 + i * ESCALA), int(bx0 + (i + 1) * ESCALA)
            bloco = opaco[ya:yb, xa:xb]
            if bloco.size == 0 or bloco.mean() <= 0.5:
                continue
            miolo = im[ya + 1:yb - 1, xa + 1:xb - 1].reshape(-1, 3)
            miolo_opaco = opaco[ya + 1:yb - 1, xa + 1:xb - 1].reshape(-1)
            amostra = miolo[miolo_opaco] if miolo_opaco.any() else im[ya:yb, xa:xb].reshape(-1, 3)[bloco.reshape(-1)]
            q[oy + j, ox + i] = (*np.median(amostra, axis=0).astype(np.uint8), 255)
    return q


origem = []
for (y0, y1) in bandas(opaco.any(1)):
    colunas = bandas(opaco[y0:y1 + 1].any(0))
    assert len(colunas) == 4, colunas
    origem.append([reduzir(y0, y1, x0, x1) for (x0, x1) in colunas])
assert len(origem) == 5

espelhar = lambda q: q[:, ::-1]
grade = [
    origem[2],
    [espelhar(q) for q in origem[1]],
    origem[3],
    origem[1],
    origem[4],
]
folha = np.zeros((F * 5, F * 4, 4), np.uint8)
for r, linha in enumerate(grade):
    for c, q in enumerate(linha):
        folha[r * F:(r + 1) * F, c * F:(c + 1) * F] = q

rgb = Image.fromarray(folha[:, :, :3]).quantize(colors=16, method=Image.Quantize.MEDIANCUT).convert('RGB')
out = np.dstack([np.array(rgb), folha[:, :, 3]])
out[out[:, :, 3] == 0, :3] = 0
Image.fromarray(out.astype(np.uint8), 'RGBA').save(RAIZ / 'recursos/arte/cachorro.png')
print('gravado recursos/arte/cachorro.png')
