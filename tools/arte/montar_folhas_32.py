"""Monta as folhas do gato tuxedo e do cachorro husky (ADR 0020).

    python tools/arte/montar_folhas_32.py

Entrada: os quadros soltos que a artista entregou, em
tools/arte/originais/gato_tuxedo/ e tools/arte/originais/cachorro_husky/
(PNG 1024x1024, pixel art 32x32 ampliada 32x, fundo transparente).

Saida: recursos/arte/gato_tuxedo.png e recursos/arte/cachorro.png, uma linha por
animacao e quadros de 32x32. Depois rode tools/gerar_sprite_frames.gd no Godot
para atualizar os SpriteFrames.

Por que um script e nao recortar no editor de imagem:
  * a reducao 1024 -> 32 e exata (cada pixel de arte e um bloco 32x32 de cor
    unica; o script confere e falha se nao for), entao refazer a arte e so
    rodar de novo, sem retoque a mao;
  * cada animacao e deslocada INTEIRA para os pes ficarem na mesma linha da
    folha (LINHA_DOS_PES). Sem isso o cachorro "pulava" 3 px ao trocar de
    frente para costas, porque as vistas foram desenhadas em alturas
    diferentes do quadro. O balanco entre quadros da mesma animacao fica
    intacto, porque o deslocamento e o mesmo para todos eles;
  * pixel opaco isolado (sem nenhum vizinho opaco) e sujeira de exportacao e
    e apagado -- o script avisa quantos achou.

Requer: pip install pillow numpy
"""
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
ORIGINAIS = RAIZ / "tools/arte/originais"
AMPLIACAO = 32          # 1024 px / 32 px de arte
QUADRO = 32             # tamanho do quadro na folha do jogo
LINHA_DOS_PES = 27      # ultima linha opaca de toda animacao (0..31)
COLUNAS = 4             # largura da folha, em quadros

# animacao -> quadros de origem, na ordem de reproducao. A ordem das linhas
# casa com FOLHAS em tools/gerar_sprite_frames.gd.
GATO = [
    ("andar_baixo", ["sprite_tuxido00", "sprite_tuxido01", "sprite_tuxido02", "sprite_tuxido03"]),
    ("andar_direita", ["sprite_tuxido04", "sprite_tuxido05", "sprite_tuxido06"]),
    ("andar_cima", ["sprite_tuxido07", "sprite_tuxido08", "sprite_tuxido09", "sprite_tuxido10"]),
    ("andar_esquerda", ["sprite_tuxido11", "sprite_tuxido12", "sprite_tuxido13"]),
    ("parado", ["sprite_tuxido14"]),
    ("descansar", ["sprite_tuxido15", "sprite_tuxido16"]),
]
CACHORRO = [
    ("andar_baixo", ["sprite_00", "sprite_01", "sprite_02"]),
    ("andar_direita", ["sprite_03", "sprite_04", "sprite_05"]),
    ("andar_cima", ["sprite_06", "sprite_07", "sprite_08", "sprite_09"]),
    ("andar_esquerda", ["sprite_10", "sprite_11", "sprite_12"]),
    ("parado", ["sprite_13", "sprite_14"]),
]


def reduzir(caminho: Path) -> np.ndarray:
    """1024x1024 -> 32x32, conferindo que cada bloco e de cor unica."""
    grande = np.array(Image.open(caminho).convert("RGBA"))
    n = grande.shape[0] // AMPLIACAO
    blocos = grande.reshape(n, AMPLIACAO, n, AMPLIACAO, 4)
    canto = blocos[:, :1, :, :1, :]
    if not (blocos == canto).all():
        raise SystemExit(f"{caminho.name}: nao e pixel art em grade de {AMPLIACAO}")
    arte = canto[:, 0, :, 0, :].copy()
    arte[arte[..., 3] < 128] = 0          # alfa binario: pixel art nao tem meio-termo
    arte[arte[..., 3] >= 128, 3] = 255
    return arte


def limpar_isolados(arte: np.ndarray) -> int:
    opaco = arte[..., 3] > 0
    viz = np.zeros_like(opaco, dtype=int)
    p = np.pad(opaco, 1)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                viz += p[1 + dy:1 + dy + opaco.shape[0], 1 + dx:1 + dx + opaco.shape[1]]
    isolados = opaco & (viz == 0)
    arte[isolados] = 0
    return int(isolados.sum())


def montar(pasta: str, animacoes: list, destino: str) -> None:
    folha = np.zeros((QUADRO * len(animacoes), QUADRO * COLUNAS, 4), np.uint8)
    for linha, (nome, quadros) in enumerate(animacoes):
        if len(quadros) > COLUNAS:
            raise SystemExit(f"{nome}: mais de {COLUNAS} quadros")
        artes = [reduzir(ORIGINAIS / pasta / f"{q}.png") for q in quadros]
        sujeira = sum(limpar_isolados(a) for a in artes)
        if sujeira:
            print(f"  {pasta}/{nome}: {sujeira} pixel(s) solto(s) removido(s)")
        uniao = np.zeros((QUADRO, QUADRO), bool)
        for a in artes:
            uniao |= a[..., 3] > 0
        ys, xs = np.where(uniao)
        dy = LINHA_DOS_PES - ys.max()
        dx = (QUADRO - 1) // 2 - (xs.min() + xs.max()) // 2
        for coluna, a in enumerate(artes):
            movida = np.roll(np.roll(a, dy, axis=0), dx, axis=1)
            folha[linha * QUADRO:(linha + 1) * QUADRO, coluna * QUADRO:(coluna + 1) * QUADRO] = movida
    Image.fromarray(folha, "RGBA").save(RAIZ / destino)
    print(f"gerado: {destino} ({folha.shape[1]}x{folha.shape[0]})")


if __name__ == "__main__":
    montar("gato_tuxedo", GATO, "recursos/arte/gato_tuxedo.png")
    montar("cachorro_husky", CACHORRO, "recursos/arte/cachorro.png")
