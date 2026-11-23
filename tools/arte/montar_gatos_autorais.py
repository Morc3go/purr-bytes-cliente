"""Monta as folhas dos tres gatos a partir da arte autoral da equipe (ADR 0024 e 0030).

    python tools/arte/montar_gatos_autorais.py

Entradas (tools/arte/originais/): as pranchas que a equipe desenhou, uma por
pelagem -- amarelo (o gato base), calico e siames. Todas tem 18 quadros em 5
linhas, pixel art ampliada e salva em JPEG. Mudam a ampliacao (8x, ou 7,8x na do
amarelo, que foi redimensionada), o ponto onde comeca a grade e a cor do fundo
(branco ou cinza); por isso cada prancha tem a sua entrada em GATOS.

    linha 0  andar_baixo     4 quadros
    linha 1  andar_direita   3 quadros
    linha 2  andar_cima      4 quadros
    linha 3  andar_esquerda  3 quadros
    linha 4  em pe (parado), sentado olho aberto x2, sentado olho fechado

Saida: recursos/arte/gato_<pelagem>.png, quadros de 32x32 com a mesma ordem de
linhas (a linha 4 vira as animacoes parado, sentado e descansar, ver
tools/gerar_sprite_frames.gd). Depois rode o gerador no Godot.

Por que um script, e nao recortar a mao:
  * JPEG nao tem transparencia e borra a cor de cada pixel de arte. O script
    le a cor no MEIO de cada bloco 8x8 (longe da borda borrada), agrupa as
    cores proximas numa paleta pequena e devolve blocos de cor unica;
  * o fundo e a cor do canto ligada a borda da imagem. O branco ou o creme do
    pelo fica, porque esta cercado pelo contorno preto;
  * os pes de cada linha vao para a mesma linha da folha (LINHA_DOS_PES) e o
    sobe-e-desce entre quadros da mesma animacao e preservado, como em
    montar_folhas_32.py;
  * no andar de lado, o que fica parado entre quadros e a CABECA, nao a caixa
    do desenho (o rabo muda de tamanho). Por isso o alinhamento horizontal e
    pela borda do focinho; de frente e de costas, pelo centro.

Requer: pip install pillow numpy scipy
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

RAIZ = Path(__file__).resolve().parents[2]

# pelagem: (prancha, ampliacao, (y, x) onde comeca o primeiro bloco inteiro).
# Ampliacao e inicio medidos pela periodicidade das bordas da prancha (o pico
# da transformada de Fourier da soma das diferencas entre pixels vizinhos).
GATOS = {
    "amarelo": ("tools/arte/originais/gato_amarelo/amarelo_autoral.jpg", 7.8, (6.1, 2.3)),
    "calico": ("tools/arte/originais/gato_calico/calico_autoral.jpg", 8.0, (2.0, 6.0)),
    "siames": ("tools/arte/originais/gato_siames/siames_autoral.jpg", 8.0, (0.0, 2.0)),
}
QUADRO = 32
COLUNAS = 4
LINHA_DOS_PES = 27         # mesma linha dos pes dos cachorros
DISTANCIA_DE_COR = 45      # cores mais proximas que isso sao a mesma cor
QUADROS_POR_LINHA = [4, 3, 4, 3, 4]
# Como alinhar cada linha na horizontal: centro, focinho a direita, a esquerda.
ALINHAMENTO = ["centro", "direita", "centro", "esquerda", "centro"]
MARGEM_LATERAL = 3


def ler_pixels(caminho: Path, ampliacao: float, inicio: tuple) -> np.ndarray:
    """Prancha -> uma cor por pixel de arte (mediana do miolo 4x4 do bloco).

    O miolo e tomado em volta do centro de cada bloco, calculado em ponto
    flutuante: assim a mesma conta serve para ampliacao inteira ou nao."""
    imagem = np.array(Image.open(caminho).convert("RGB")).astype(int)
    oy, ox = inicio
    altura = int((imagem.shape[0] - oy) // ampliacao)
    largura = int((imagem.shape[1] - ox) // ampliacao)
    deslocamentos = np.array([-1.5, -0.5, 0.5, 1.5])
    ys = (oy + (np.arange(altura) + 0.5) * ampliacao)[:, None] + deslocamentos[None]
    xs = (ox + (np.arange(largura) + 0.5) * ampliacao)[:, None] + deslocamentos[None]
    ys = np.clip(np.floor(ys).astype(int), 0, imagem.shape[0] - 1)
    xs = np.clip(np.floor(xs).astype(int), 0, imagem.shape[1] - 1)
    miolo = imagem[ys[:, None, :, None], xs[None, :, None, :]]   # (alt, larg, 4, 4, 3)
    return np.median(miolo.reshape(altura, largura, 16, 3), axis=2)


def limpar_paleta(pixels: np.ndarray) -> np.ndarray:
    """Agrupa as cores do JPEG numa paleta e troca cada pixel pela cor do grupo."""
    cores = pixels.reshape(-1, 3)
    paleta: list = []
    for cor in cores:
        if not any(np.abs(cor - p).sum() < DISTANCIA_DE_COR for p in paleta):
            paleta.append(cor)
    paleta = np.array(paleta, float)
    for _ in range(10):
        grupo = ((cores[:, None, :] - paleta[None]) ** 2).sum(-1).argmin(1)
        paleta = np.array([cores[grupo == i].mean(0) if (grupo == i).any() else paleta[i]
                           for i in range(len(paleta))])
    paleta = paleta.round().clip(0, 255).astype(np.uint8)
    return paleta[grupo].reshape(pixels.shape[0], pixels.shape[1], 3)


def recortar(arte: np.ndarray) -> list:
    """Separa os desenhos e devolve [(caixa, rgba)] agrupados por linha."""
    fundo_cor = arte[0, 0]
    branco = (arte == fundo_cor).all(-1)
    rotulos, _ = ndimage.label(branco)
    da_borda = set(np.unique(np.concatenate(
        [rotulos[0], rotulos[-1], rotulos[:, 0], rotulos[:, -1]]))) - {0}
    fundo = np.isin(rotulos, list(da_borda))
    rgba = np.dstack([arte, np.where(fundo, 0, 255).astype(np.uint8)])
    desenhos, quantos = ndimage.label(~fundo, structure=np.ones((3, 3)))
    caixas = ndimage.find_objects(desenhos)
    if quantos != sum(QUADROS_POR_LINHA):
        raise SystemExit(f"esperava {sum(QUADROS_POR_LINHA)} desenhos, achei {quantos}")
    itens = []
    for i, caixa in enumerate(caixas):
        so_este = rgba[caixa].copy()
        so_este[desenhos[caixa] != i + 1] = 0
        itens.append((caixa, so_este))
    itens.sort(key=lambda item: item[0][0].stop)
    linhas, inicio = [], 0
    for n in QUADROS_POR_LINHA:
        linha = sorted(itens[inicio:inicio + n], key=lambda item: item[0][1].start)
        linhas.append(linha)
        inicio += n
    return linhas


def montar_folha(linhas: list) -> np.ndarray:
    folha = np.zeros((QUADRO * len(linhas), QUADRO * COLUNAS, 4), np.uint8)
    for indice, (linha, alinhamento) in enumerate(zip(linhas, ALINHAMENTO)):
        pes = max(caixa[0].stop for caixa, _ in linha)
        for coluna, (caixa, desenho) in enumerate(linha):
            altura, largura = desenho.shape[:2]
            if altura > QUADRO or largura > QUADRO - MARGEM_LATERAL:
                raise SystemExit(f"linha {indice}: desenho {largura}x{altura} nao cabe em {QUADRO}")
            topo = LINHA_DOS_PES + 1 - (pes - caixa[0].start)
            if alinhamento == "direita":
                esquerda = QUADRO - MARGEM_LATERAL - largura
            elif alinhamento == "esquerda":
                esquerda = MARGEM_LATERAL
            else:
                esquerda = (QUADRO - largura) // 2
            y0, x0 = indice * QUADRO + topo, coluna * QUADRO + esquerda
            alvo = folha[y0:y0 + altura, x0:x0 + largura]
            opaco = desenho[..., 3] > 0
            alvo[opaco] = desenho[opaco]
    return folha


def main() -> None:
    for pelagem, (origem, ampliacao, inicio) in GATOS.items():
        arte = limpar_paleta(ler_pixels(RAIZ / origem, ampliacao, inicio))
        folha = montar_folha(recortar(arte))
        destino = RAIZ / f"recursos/arte/gato_{pelagem}.png"
        Image.fromarray(folha, "RGBA").save(destino)
        cores = len(np.unique(folha[folha[..., 3] > 0][:, :3], axis=0))
        print(f"gerado: {destino.relative_to(RAIZ)} ({folha.shape[1]}x{folha.shape[0]}, {cores} cores)")


if __name__ == "__main__":
    main()
