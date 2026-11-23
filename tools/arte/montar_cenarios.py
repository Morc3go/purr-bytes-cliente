"""Monta a arte dos cenarios do labirinto e a porta em arco (ADR 0035).

    python tools/arte/montar_cenarios.py

Entrada, em tools/arte/originais/cenarios/ (arte enviada pela equipe):
  * agua.jpg: quatro ladrilhos de agua de 32x32 pixels de arte (um com o sapinho);
  * enfeites.jpg: folha de arvores, moitas, pedras e miudezas (so as miudezas
    entram no jogo, reduzidas, sem a grama da base e na cor de cada cenario);
  * portas.jpg: portas em arco de pedra (a de madeira lisa e a usada);
  * madeira_e_pedras.jpg: de onde saiu a paleta das tabuas do deck do lago;
  * boneco_de_neve.jpg: referencia do boneco de neve, redesenhado em 13x16.
Tambem usa recursos/arte/grama.png e arbusto_pecas.png (o jardim original), que
sao recoloridos para cada cenario: mesmo desenho, outra paleta.

Saida:
  * recursos/arte/cenarios/<cenario>/chao.png e muro.png (ou agua.png no lago),
    mais os enfeites daquele cenario;
  * recursos/arte/porta_fechada.png e porta_aberta.png: o arco de pedra em
    18x16, uma celula do labirinto (a porta antiga tinha 24x32 e subia pela cerca).

Tudo e deterministico: rodar de novo gera os mesmos arquivos.

Requer: pip install pillow numpy scipy
"""
import colorsys
import random
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

RAIZ = Path(__file__).resolve().parents[2]
ORIGINAIS = RAIZ / "tools/arte/originais/cenarios"
ARTE = RAIZ / "recursos/arte"
CENARIOS = ARTE / "cenarios"


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def salvar(img, cenario, nome):
    pasta = CENARIOS / cenario
    pasta.mkdir(parents=True, exist_ok=True)
    img.save(pasta / f"{nome}.png")


def hsv(a):
    f = a[..., :3] / 255.0
    mx, mn = f.max(-1), f.min(-1)
    d = mx - mn + 1e-9
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = np.where(mx > 0, d / (mx + 1e-9), 0)
    return h, s, mx


def amostrar(imagem, arte, recorte=None):
    """Reduz pixel art ampliada ao pixel de arte, pegando o centro de cada bloco."""
    im = imagem.crop(recorte) if recorte else imagem
    w, h = im.size
    a = np.array(im)
    ys = ((np.arange(arte[1]) + 0.5) * h / arte[1]).astype(int)
    xs = ((np.arange(arte[0]) + 0.5) * w / arte[0]).astype(int)
    return Image.fromarray(a[ys][:, xs])


# Paletas de cada cenario: rampa do arbusto (escuro -> claro), contorno e terra.
RAMPAS = {
    "outono": (["#6b2a1e", "#a8432a", "#d9752f", "#f2b04a"], "#2e1a1a", "#5a3a2a"),
    "cerejeira": (["#7d3c63", "#b85a8c", "#e68ab3", "#f8c6dc"], "#3a2335", "#6b4a5a"),
    "inverno": (["#1d3d3c", "#2c5c56", "#d4e6ee", "#ffffff"], "#1a2630", "#4a5a66"),
    "ruinas": (["#3b3d45", "#62646c", "#8f9197", "#c3c2bd"], "#24252b", "#4a3f3a"),
    "bosque": (["#1d2f5a", "#2c5490", "#3f88b8", "#8fd6e6"], "#121a33", "#2a2a4a"),
    "lavanda": (["#4a2f6b", "#7a52a6", "#a682d1", "#d8c4f2"], "#2a1d3a", "#5a4a6a"),
}
# Chao: as seis cores da grama do jardim, trocadas uma a uma.
GRAMA_ORIGEM = ["#689f39", "#548b2e", "#33531f", "#95bc77", "#fafae7", "#fad830"]
CHAOS = {
    "outono": ["#9a8f3e", "#85792f", "#5a4a22", "#c2b45f", "#e8743a", "#f2c14e"],
    "cerejeira": ["#f0c2d0", "#e4adc0", "#c78a9f", "#f9dde6", "#ffffff", "#f6d36b"],
    "inverno": ["#e6eef2", "#cfdbe3", "#9fb2c2", "#ffffff", "#a9d4f5", "#ffffff"],
    "ruinas": ["#c8a874", "#b39260", "#7d6444", "#dcc394", "#efe3c8", "#a08868"],
    "bosque": ["#2e5a4a", "#264c3f", "#173229", "#3f7a63", "#9ad9ff", "#e8fbff"],
    "lavanda": ["#a6c98a", "#91b876", "#5f8a4a", "#c4deb0", "#ffffff", "#f6d36b"],
}


def montar_chaos_e_muros():
    grama = np.array(Image.open(ARTE / "grama.png").convert("RGB")).astype(int)
    for cenario, destino in CHAOS.items():
        saida = grama.copy()
        for o, d in zip(GRAMA_ORIGEM, destino):
            saida[(grama == hexc(o)).all(-1)] = hexc(d)
        salvar(Image.fromarray(saida.astype(np.uint8)), cenario, "chao")

    pecas = np.array(Image.open(ARTE / "arbusto_pecas.png").convert("RGBA")).astype(int)

    def classificar(c):
        r, g, b = c
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        if g >= r and g >= b - 10 and l > 0.22 and s > 0.12:
            return "verde"
        if r > g + 8:
            return "terra"
        return "contorno"

    opacas = {tuple(c) for c in pecas[pecas[..., 3] > 0][:, :3]}
    verdes = sorted([c for c in opacas if classificar(c) == "verde"],
                    key=lambda c: 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2])
    for cenario, (rampa, contorno, terra) in RAMPAS.items():
        mapa = {c: hexc(rampa[round(i / max(1, len(verdes) - 1) * (len(rampa) - 1))]) for i, c in enumerate(verdes)}
        saida = pecas.copy()
        for y in range(saida.shape[0]):
            for x in range(saida.shape[1]):
                if saida[y, x, 3] == 0:
                    continue
                c = tuple(saida[y, x, :3])
                k = classificar(c)
                saida[y, x, :3] = mapa[c] if k == "verde" else (hexc(terra) if k == "terra" else hexc(contorno))
        salvar(Image.fromarray(saida.astype(np.uint8)), cenario, "muro")


def montar_lago():
    """Lago com passarelas: chao de tabuas e agua no lugar da cerca."""
    agua = Image.open(ORIGINAIS / "agua.jpg").convert("RGB")
    im = np.array(agua).astype(int)
    teal = (im[..., 2] > 140) & (im[..., 1] > 150) & (im[..., 0] < 170)
    lab, _ = ndimage.label(teal)
    caixas = sorted([s for s in ndimage.find_objects(lab) if (s[0].stop - s[0].start) > 150],
                    key=lambda s: (s[0].start // 100, s[1].start))
    ladrilhos = [amostrar(agua, (32, 32), (s[1].start, s[0].start, s[1].stop, s[0].stop)) for s in caixas]
    salvar(ladrilhos[0], "lago", "agua")
    # o sapinho do ladrilho com borda, sem a agua em volta
    sapo = np.array(ladrilhos[2].convert("RGBA"))
    regiao = sapo[11:23, 9:21].copy()
    regiao[np.abs(regiao[..., :3].astype(int) - regiao[0, 0, :3]).sum(-1) < 40, 3] = 0
    sapo_img = Image.fromarray(regiao)
    sapo_img = sapo_img.crop(sapo_img.getbbox())

    def folha(flor=False):
        a = np.zeros((9, 12, 4), np.uint8)
        cx, cy = 5.5, 4.0
        for y in range(9):
            for x in range(12):
                d = ((x - cx) / 5.6) ** 2 + ((y - cy) / 4.2) ** 2
                if d > 1.0:
                    continue
                angulo = np.degrees(np.arctan2(y - cy, x - cx))
                if -18 < angulo < 18 and x > cx:
                    continue           # o corte em V da vitoria-regia
                cor = "#2f6a2a" if d > 0.72 else ("#6fbf4f" if (y < cy - 1 and x < cx) else "#4f9a3c")
                a[y, x] = (*hexc(cor), 255)
        if flor:
            for x, y, c in [(4, 3, "#f8c6dc"), (5, 3, "#f4a6c8"), (4, 4, "#f4a6c8"), (5, 4, "#fff6a8"),
                            (6, 4, "#f4a6c8"), (5, 5, "#f8c6dc"), (4, 2, "#ffffff")]:
                a[y, x] = (*hexc(c), 255)
        return Image.fromarray(a, "RGBA")

    salvar(folha(), "lago", "vitoria_regia")
    salvar(folha(True), "lago", "vitoria_regia_flor")
    base = Image.new("RGBA", (max(12, sapo_img.width), 9 + sapo_img.height - 5), (0, 0, 0, 0))
    f = folha()
    base.paste(f, (0, base.height - 9), f)
    base.paste(sapo_img, ((base.width - sapo_img.width) // 2, 0), sapo_img)
    salvar(base, "lago", "sapo_na_folha")

    # deck de tabuas, nas cores da madeira de madeira_e_pedras.jpg
    rnd = random.Random(7)
    BASE, CLARA, ESCURA, LINHA, PREGO = hexc("#dc8c5c"), hexc("#efa577"), hexc("#b9693b"), hexc("#7a3e22"), hexc("#5a2e1a")
    deck = np.zeros((64, 64, 3), int)
    for faixa in range(8):
        y0 = faixa * 8
        deck[y0:y0 + 8] = BASE
        deck[y0 + 1, :] = CLARA
        deck[y0 + 6, :] = ESCURA
        deck[y0 + 7, :] = LINHA
        x = rnd.randrange(0, 64)
        while True:
            x = (x + rnd.randrange(20, 36)) % 64
            deck[y0:y0 + 7, x] = LINHA
            deck[y0 + 3, (x + 2) % 64] = PREGO
            deck[y0 + 3, (x - 2) % 64] = PREGO
            if rnd.random() < 0.45:
                break
        for _ in range(5):
            gx, gy = rnd.randrange(64), y0 + rnd.choice([2, 3, 4, 5])
            for k in range(rnd.randrange(3, 7)):
                if deck[gy, (gx + k) % 64].tolist() == list(BASE):
                    deck[gy, (gx + k) % 64] = ESCURA if k % 3 else CLARA
    salvar(Image.fromarray(deck.astype(np.uint8)), "lago", "chao")


def reduzir(rgba, largura_max, altura_max, cores=12):
    """Recorte em alta -> pixel art pequena: media por bloco e paleta curta."""
    alfa = rgba[..., 3]
    escala = min(largura_max / rgba.shape[1], altura_max / rgba.shape[0])
    w, h = max(3, round(rgba.shape[1] * escala)), max(3, round(rgba.shape[0] * escala))
    pre = np.dstack([rgba[..., :3] * (alfa[..., None] > 0), alfa]).astype(np.uint8)
    p = np.array(Image.fromarray(pre, "RGBA").resize((w, h), Image.BOX)).astype(float)
    a = p[..., 3]
    cor = np.clip(np.where(a[..., None] > 0, p[..., :3] * 255.0 / np.maximum(a[..., None], 1), 0), 0, 255).astype(np.uint8)
    q = np.array(Image.fromarray(cor).quantize(cores, method=Image.Quantize.MEDIANCUT).convert("RGB"))
    img = Image.fromarray(np.dstack([q, np.where(a > 120, 255, 0).astype(np.uint8)]), "RGBA")
    return img.crop(img.getbbox())


def sem_graminha(rgba, limite=0.72):
    """Tira o tufo de grama da base: abaixo do corpo do desenho, so o tronco fica."""
    h, s, v = hsv(rgba)
    opaco = rgba[..., 3] > 0
    largura = rgba.shape[1]
    linhas = np.where(opaco.sum(1) > 0.42 * largura)[0]
    linhas = linhas[linhas < rgba.shape[0] * limite]
    if linhas.size == 0:
        return rgba
    fim = linhas.max() + 2
    marrom = (h > 5) & (h < 50) & (s > 0.22) & (v < 0.8)
    escuro = (v < 0.42) & (s < 0.55)
    colunas = np.where((marrom | escuro)[fim:].sum(0) > 1)[0]
    manter = np.zeros_like(opaco)
    if colunas.size:
        meio, meia = int(np.median(colunas)), max(3, int(largura * 0.09))
        faixa = np.zeros(largura, bool)
        faixa[max(0, meio - meia):meio + meia + 1] = True
        manter = (marrom | escuro) & faixa[None, :]
    abaixo = np.zeros_like(opaco)
    abaixo[fim:] = True
    rgba[..., 3] = np.where(abaixo & ~manter, 0, rgba[..., 3])
    lab, n = ndimage.label(rgba[..., 3] > 0)
    if n > 1:
        maior = np.argmax(ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))) + 1
        rgba[lab != maior, 3] = 0
    return rgba


def na_cor_do_cenario(img, cenario):
    """O verde de um enfeite vira a rampa do cenario: nada de verde na neve."""
    a = np.array(img.convert("RGBA")).astype(int)
    rampa = [np.array(hexc(c)) for c in RAMPAS[cenario][0]]
    verdes = []
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            if a[y, x, 3] == 0:
                continue
            h, l, _ = colorsys.rgb_to_hls(*(a[y, x, :3] / 255))
            _, s, _ = colorsys.rgb_to_hsv(*(a[y, x, :3] / 255))
            # saturacao de HSV: pega tambem o verde-acinzentado das hastes
            if 55 / 360 < h < 175 / 360 and s > 0.15:
                verdes.append((y, x, l))
    if verdes:
        ls = np.array([v[2] for v in verdes])
        lo, hi = ls.min(), ls.max()
        for y, x, l in verdes:
            a[y, x, :3] = rampa[0 if hi == lo else int(round((l - lo) / (hi - lo) * 3))]
    return Image.fromarray(a.astype(np.uint8))


def montar_enfeites():
    folha = np.array(Image.open(ORIGINAIS / "enfeites.jpg").convert("RGB")).astype(int)
    sat = folha.max(-1) - folha.min(-1)
    fundo = (sat < 26) & (folha.min(-1) > 182)
    lab, _ = ndimage.label(~fundo)
    caixas = [s for s in ndimage.find_objects(lab)
              if (s[0].stop - s[0].start) * (s[1].stop - s[1].start) > 400 and s[0].start < 850]
    linhas = {}
    for s in sorted(caixas, key=lambda s: s[0].start):
        chave = next((k for k in linhas if abs(k - s[0].start) < 45), s[0].start)
        linhas.setdefault(chave, []).append(s)
    linhas = [sorted(linhas[k], key=lambda s: s[1].start) for k in sorted(linhas)]

    def recorte(linha, coluna):
        s = linhas[linha][coluna]
        y0, y1, x0, x1 = s[0].start, s[0].stop, s[1].start, s[1].stop
        rgba = np.dstack([folha[y0:y1, x0:x1], np.where(lab[y0:y1, x0:x1] > 0, 255, 0)]).astype(float)
        rgba[fundo[y0:y1, x0:x1], 3] = 0
        return rgba

    # (linha, coluna) na folha, se tira a grama da base, e onde entra
    ENFEITES = {
        "folhas_secas": ((5, 5), True, ["outono"]),
        "cogumelos": ((6, 5), True, ["outono", "ruinas", "bosque"]),
        "cogumelos_vermelhos": ((6, 4), True, ["outono"]),
        "moita_flor_rosa": ((2, 0), False, ["cerejeira"]),
        "flor_branca": ((3, 2), False, ["cerejeira", "lavanda"]),
        "rocha": ((4, 0), True, ["ruinas"]),
        "seixos": ((6, 0), False, ["ruinas"]),
        "toco": ((5, 0), True, ["ruinas"]),
        "flores_azuis": ((3, 1), False, ["bosque"]),
        "lavanda": ((3, 3), False, ["lavanda"]),
    }
    for nome, ((l, c), tirar_grama, cenarios) in ENFEITES.items():
        rgba = recorte(l, c)
        if tirar_grama:
            rgba = sem_graminha(rgba)
        pequeno = reduzir(rgba, 10, 10, 10)
        for cenario in cenarios:
            salvar(na_cor_do_cenario(pequeno, cenario), cenario, nome)


def montar_boneco_de_neve():
    """O boneco da equipe, redesenhado para caber numa celula (13x16)."""
    grade = [
        "....OOOOO....", "....OHhHO....", "....OHHHO....", "....ORRRO....",
        "..OOOOOOOOO..", "...OWWWWWO...", "...OWkWkWO...", "..NNnWWWsO...",
        "S..OsbbbsO..S", ".S.OWWkWWO.S.", "..SOWWWWsOS..", ".OOWWWkWWsOO.",
        ".OWWWWWWWWsO.", ".OWWWWkWWWsO.", ".OssWWWWWssO.", "..OOOOOOOOO..",
    ]
    cores = {"O": "#2a1515", "H": "#2f3640", "h": "#6a7480", "R": "#c0303a", "W": "#eef4f8", "s": "#a9c2d2",
             "b": "#7895a8", "k": "#2a1515", "N": "#e8762d", "n": "#b8541c", "S": "#3a2218"}
    a = np.zeros((len(grade), len(grade[0]), 4), np.uint8)
    for y, linha in enumerate(grade):
        for x, c in enumerate(linha):
            if c != ".":
                a[y, x] = (*hexc(cores[c]), 255)
    salvar(Image.fromarray(a, "RGBA"), "inverno", "boneco_de_neve")


def montar_porta():
    """Arco de pedra com porta de madeira, em 18x16; a aberta mostra a passagem escura."""
    portas = np.array(Image.open(ORIGINAIS / "portas.jpg").convert("RGB")).astype(int)
    fundo = np.array([43, 61, 73])
    x0, y0, x1, y1 = 291, 247, 429, 371          # a porta de madeira lisa, a do meio
    reg = portas[y0:y1, x0:x1]
    rgba = np.dstack([reg, np.where(np.abs(reg - fundo).sum(-1) > 45, 255, 0)]).astype(float)
    largura = 18
    alto, larg = rgba.shape[:2]
    altura = round(alto * largura / larg)
    p = np.zeros((altura, largura, 4), np.uint8)
    for y in range(altura):
        for x in range(largura):
            bloco = rgba[int(y * alto / altura):int((y + 1) * alto / altura), int(x * larg / largura):int((x + 1) * larg / largura)]
            opacos = bloco[bloco[..., 3] > 0]
            if len(opacos) < bloco.shape[0] * bloco.shape[1] * 0.45:
                continue
            chaves = (opacos[:, :3] // 24).astype(int)
            valores, contagem = np.unique(chaves, axis=0, return_counts=True)
            alvo = valores[np.argmax(contagem)]
            p[y, x, :3] = opacos[(chaves == alvo).all(1)][:, :3].mean(0)
            p[y, x, 3] = 255
    h, s, _ = hsv(p.astype(float))
    madeira = (p[..., 3] > 0) & ((h < 45) | (h > 335)) & (s > 0.3)
    # aberta: a folha de madeira vira o escuro de dentro
    aberta = p.copy()
    interior = ndimage.binary_fill_holes(madeira) | ndimage.binary_closing(madeira, iterations=2)
    aberta[interior] = [28, 22, 30, 255]
    for y in np.where(interior.any(1))[0][:3]:
        aberta[y, np.where(interior[y])[0]] = [44, 36, 46, 255]
    # fechada: as duas frestas das tabuas, que a reducao apagava
    cols = np.where(madeira.any(0))[0]
    for x in (cols.min() + (cols.max() - cols.min() + 1) // 3, cols.min() + 2 * (cols.max() - cols.min() + 1) // 3):
        ys = np.where(madeira[:, x])[0]
        p[ys[1:], x, :3] = (p[ys[1:], x, :3] * 0.62).astype(np.uint8)
    Image.fromarray(p, "RGBA").save(ARTE / "porta_fechada.png")
    Image.fromarray(aberta, "RGBA").save(ARTE / "porta_aberta.png")


if __name__ == "__main__":
    montar_chaos_e_muros()
    montar_lago()
    montar_enfeites()
    montar_boneco_de_neve()
    montar_porta()
    for pasta in sorted(CENARIOS.iterdir()):
        print(f"gerado: recursos/arte/cenarios/{pasta.name}/ ({', '.join(sorted(p.stem for p in pasta.glob('*.png')))})")
    print("gerado: recursos/arte/porta_fechada.png e porta_aberta.png (18x16)")
