"""Monta os itens que marcam os pacotes no labirinto (ADR 0043).

    python tools/arte/montar_itens.py

Entrada: tools/arte/originais/itens/ (novelo, peixe, rato), desenhados pela
equipe ja no tamanho do jogo. O peixe de olho amarelo veio junto mas nao e
usado: a equipe escolheu o de olho preto (peixe.png).

Saida: recursos/arte/itens/<nome>.png, cada um recortado ao menor retangulo que
cabe o desenho, para o item ficar centrado na celula. A transparencia vira 0 ou
255 (pixel art sem meio-termo, como nas folhas dos personagens).
"""

from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
ORIGINAIS = RAIZ / "tools" / "arte" / "originais" / "itens"
DESTINO = RAIZ / "recursos" / "arte" / "itens"
ITENS = ["novelo", "peixe", "rato"]


def main() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    for nome in ITENS:
        arte = np.array(Image.open(ORIGINAIS / f"{nome}.png").convert("RGBA"))
        opaco = arte[..., 3] >= 128
        arte[~opaco] = 0
        arte[opaco, 3] = 255
        ys, xs = np.where(opaco)
        recorte = arte[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        Image.fromarray(recorte, "RGBA").save(DESTINO / f"{nome}.png")
        print(f"gerado: recursos/arte/itens/{nome}.png ({recorte.shape[1]}x{recorte.shape[0]})")


if __name__ == "__main__":
    main()
