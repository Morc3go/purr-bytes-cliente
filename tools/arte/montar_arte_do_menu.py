"""Monta a arte do menu (fundos e botoes) e da porta de saida (ADR 0027, 0029 e 0033).

    python tools/arte/montar_arte_do_menu.py

Entrada, em tools/arte/originais/menu/ (as tres vieram em JPEG):
  * pantano.jpg: brejo com vitorias-regias e sapinhos em pixel art, 736x414
    (substituiu a floresta da ADR 0027);
  * balao.jpg: moldura verde com flores nos cantos, sobre fundo preto (o
    "transparente" virou preto no JPEG);
  * porta.jpg: porta fechada, porta de lado e porta aberta, ampliadas 7,25x,
    sobre fundo branco.

Os outros fundos da galeria do menu (ADR 0033) ficam em
tools/arte/originais/menu/fundos/: ceu, noite, estufa, carpas e piquenique.

Saida, em recursos/arte/:
  * fundos/<nome>.png (640x360), um por fundo da galeria: recortado em 16:9,
    reduzido a uma grade de 320x180 e ampliado 2x. O dobro do detalhe do
    antigo wallpaper de neve (160x90), porque folhagem e capim finos somem
    numa grade menor;
  * balao_botao_<nome>.png: a moldura dos botoes recolorida no tom de cada
    fundo. So o verde muda; flores, contorno e sombreado ficam;
  * balao_botao.png (71x41): a moldura, usada como "nine-patch" nos botoes do
    menu. As quinas (flores) ficam do tamanho original e o miolo verde estica
    para caber o texto;
  * porta_fechada.png e porta_aberta.png (24x32 e 24x34).

O que todas tem em comum: o JPEG borra cada pixel de arte. Le-se a cor no meio
de cada bloco, agrupam-se as cores parecidas numa paleta pequena (sem perder as
cores raras, como o rosa e o branco das flores) e o fundo vira transparente por
"inundacao" a partir da borda da imagem, entao o branco ou o preto DENTRO do
desenho nao some.

Requer: pip install pillow numpy scipy
"""
import colorsys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

RAIZ = Path(__file__).resolve().parents[2]
ORIGINAIS = RAIZ / "tools/arte/originais/menu"
ARTE = RAIZ / "recursos/arte"

GRADE_WALLPAPER = (320, 180)
CORES_WALLPAPER = 40

# Galeria do menu (ADR 0033): nome -> (arquivo original, recorte ou None para o
# meio em 16:9, cores da paleta, cor do balao ou None para o verde original).
# O recorte do piquenique deixa de fora a marca d'agua do canto. As carpas
# precisam de mais cores: com 40, o laranja dos peixes virava amarelo-palido.
FUNDOS = {
    "brejo": ("pantano.jpg", None, 40, None),
    "ceu": ("fundos/ceu.jpg", None, 40, "6f9fb8"),
    "noite": ("fundos/noite.jpg", None, 40, "3f72a3"),
    "estufa": ("fundos/estufa.jpg", None, 40, "5fa58a"),
    "carpas": ("fundos/carpas.jpg", None, 96, "e0893a"),
    "piquenique": ("fundos/piquenique.jpg", (30, 0, 705, 380), 40, "a8743f"),
}
# Moldura: recorte da imagem sem a sobra preta e altura final em pixels de
# arte. 41 e o meio-termo: flores ainda legiveis e botao que cabe 5 vezes no
# cartao do menu.
RECORTE_BALAO = (13, 18, 312, 190)
ALTURA_BALAO = 41
# Porta: tamanho do pixel de arte na prancha e deslocamento da grade.
GRADE_PORTA = (7.25, 0.5, 0.0)
DISTANCIA_DE_COR = 40


def paleta(cores: np.ndarray, distancia: float) -> np.ndarray:
    """Agrupa cores parecidas mantendo as raras (cada grupo nasce de uma cor real)."""
    grupos: list = []
    for cor in cores:
        if not any(np.abs(cor - g).sum() < distancia for g in grupos):
            grupos.append(cor)
    grupos = np.array(grupos)
    for _ in range(12):
        qual = ((cores[:, None] - grupos[None]) ** 2).sum(-1).argmin(1)
        grupos = np.array([cores[qual == i].mean(0) if (qual == i).any() else grupos[i]
                           for i in range(len(grupos))])
    return grupos.round().clip(0, 255).astype(np.uint8)[qual]


def fundo_pela_borda(mascara: np.ndarray) -> np.ndarray:
    """Pixels da mascara ligados a borda da imagem: e o fundo, nao o desenho."""
    rotulos, _ = ndimage.label(mascara)
    da_borda = set(np.unique(np.concatenate(
        [rotulos[0], rotulos[-1], rotulos[:, 0], rotulos[:, -1]]))) - {0}
    return np.isin(rotulos, list(da_borda))


def recortar_16_9(imagem: Image.Image) -> Image.Image:
    largura, altura = imagem.size
    if largura / altura > 16 / 9:
        nova = round(altura * 16 / 9)
        esquerda = (largura - nova) // 2
        return imagem.crop((esquerda, 0, esquerda + nova, altura))
    nova = round(largura * 9 / 16)
    topo = (altura - nova) // 2
    return imagem.crop((0, topo, largura, topo + nova))


def montar_fundos() -> None:
    (ARTE / "fundos").mkdir(exist_ok=True)
    for nome, (arquivo, recorte, cores, _) in FUNDOS.items():
        imagem = Image.open(ORIGINAIS / arquivo).convert("RGB")
        imagem = imagem.crop(recorte) if recorte else imagem
        imagem = recortar_16_9(imagem).resize(GRADE_WALLPAPER, Image.BOX)
        metodo = Image.Quantize.MEDIANCUT if cores <= 64 else Image.Quantize.FASTOCTREE
        arte = imagem.quantize(colors=cores, method=metodo, dither=Image.Dither.NONE)
        arte.convert("RGB").resize((GRADE_WALLPAPER[0] * 2, GRADE_WALLPAPER[1] * 2), Image.NEAREST) \
            .save(ARTE / "fundos" / f"{nome}.png")
        print(f"gerado: recursos/arte/fundos/{nome}.png (640x360, {cores} cores)")


def recolorir_balao(alvo: str) -> np.ndarray:
    """Troca o verde da moldura pelo tom `alvo`, mantendo o sombreado.

    Cada pixel verde (matiz entre ~58 e ~115 graus, bem saturado) ganha o matiz
    do alvo; o brilho e proporcional ao brilho original em relacao ao verde do
    miolo (V = 0,70). Flores, contorno e o branco das petalas nao sao verdes e
    ficam como estao."""
    imagem = np.array(Image.open(ARTE / "balao_botao.png").convert("RGBA")).astype(float)
    th, ts, tv = colorsys.rgb_to_hsv(*[int(alvo[i:i + 2], 16) / 255 for i in (0, 2, 4)])
    for y in range(imagem.shape[0]):
        for x in range(imagem.shape[1]):
            r, g, b, a = imagem[y, x]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.16 < h < 0.32 and s > 0.55:
                novo_v = min(1.0, tv * v / 0.70)
                novo_s = min(1.0, ts * (1.0 + (0.70 - v) * 0.4))
                imagem[y, x, :3] = [c * 255 for c in colorsys.hsv_to_rgb(th, novo_s, novo_v)]
    return imagem.round().clip(0, 255).astype(np.uint8)


def montar_baloes_da_galeria() -> None:
    for nome, (_, _, _, alvo) in FUNDOS.items():
        if alvo is None:
            continue
        Image.fromarray(recolorir_balao(alvo), "RGBA").save(ARTE / f"balao_botao_{nome}.png")
        print(f"gerado: recursos/arte/balao_botao_{nome}.png (tom #{alvo})")


def montar_icone_da_galeria() -> None:
    """Icone do botao da galeria: um quadrinho com montanha e sol, 13x11, em 2x."""
    desenho = [
        "KKKKKKKKKKKKK",
        "KWWWWWWWWWWWK",
        "KWccccccsscWK",
        "KWccccccsscWK",
        "KWcccgccccWWK",
        "KWccgggcccWWK",
        "KWcgggggcgWWK",
        "KWgggggggggWK",
        "KWgggggggggWK",
        "KWWWWWWWWWWWK",
        "KKKKKKKKKKKKK",
    ]
    cores = {"K": (47, 74, 53, 255), "W": (255, 255, 255, 255), "c": (162, 219, 249, 255),
             "s": (246, 200, 48, 255), "g": (79, 137, 65, 255)}
    pixels = np.array([[cores[letra] for letra in linha] for linha in desenho], dtype=np.uint8)
    imagem = Image.fromarray(pixels, "RGBA")
    imagem.resize((imagem.width * 2, imagem.height * 2), Image.NEAREST).save(ARTE / "icone_galeria.png")
    print("gerado: recursos/arte/icone_galeria.png (26x22)")


def montar_balao() -> None:
    imagem = np.array(Image.open(ORIGINAIS / "balao.jpg").convert("RGB")
                      .crop(RECORTE_BALAO)).astype(float)
    passo = imagem.shape[0] / ALTURA_BALAO
    largura = int(round(imagem.shape[1] / passo))
    pixels = np.zeros((ALTURA_BALAO, largura, 3))
    for j in range(ALTURA_BALAO):
        for i in range(largura):
            bloco = imagem[int(j * passo):int((j + 1) * passo), int(i * passo):int((i + 1) * passo)]
            pixels[j, i] = np.median(bloco.reshape(-1, 3), 0)
    cores = paleta(pixels.reshape(-1, 3), 55).reshape(pixels.shape)
    fundo = fundo_pela_borda(cores.astype(int).sum(-1) < 110)
    rgba = np.dstack([cores, np.where(fundo, 0, 255)]).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(ARTE / "balao_botao.png")
    print(f"gerado: recursos/arte/balao_botao.png ({largura}x{ALTURA_BALAO})")


def montar_portas() -> None:
    passo, ox, oy = GRADE_PORTA
    imagem = np.array(Image.open(ORIGINAIS / "porta.jpg").convert("RGB")).astype(float)
    linhas = int((imagem.shape[0] - oy) // passo)
    colunas = int((imagem.shape[1] - ox) // passo)
    pixels = np.zeros((linhas, colunas, 3))
    for j in range(linhas):
        for i in range(colunas):
            cy, cx = int(oy + (j + 0.5) * passo), int(ox + (i + 0.5) * passo)
            pixels[j, i] = np.median(imagem[cy - 1:cy + 2, cx - 1:cx + 2].reshape(-1, 3), 0)
    cores = paleta(pixels.reshape(-1, 3), DISTANCIA_DE_COR).reshape(pixels.shape)
    fundo = fundo_pela_borda(cores.astype(int).min(-1) > 215)
    rgba = np.dstack([cores, np.where(fundo, 0, 255)]).astype(np.uint8)
    desenhos, _ = ndimage.label(~fundo, structure=np.ones((3, 3)))
    caixas = sorted((c for c in ndimage.find_objects(desenhos)
                     if (c[0].stop - c[0].start) * (c[1].stop - c[1].start) > 200),
                    key=lambda c: c[1].start)
    # Da esquerda para a direita: fechada e aberta (a fina do meio, de lado, nao entra).
    for nome, caixa in (("porta_fechada", caixas[0]), ("porta_aberta", caixas[-1])):
        recorte = rgba[caixa]
        Image.fromarray(recorte, "RGBA").save(ARTE / f"{nome}.png")
        print(f"gerado: recursos/arte/{nome}.png ({recorte.shape[1]}x{recorte.shape[0]})")


if __name__ == "__main__":
    montar_fundos()
    montar_balao()
    montar_baloes_da_galeria()
    montar_icone_da_galeria()
    # A porta de saida passou a ser o arco de pedra (ADR 0035), gerado por
    # tools/arte/montar_cenarios.py; montar_portas() fica so como historico.
