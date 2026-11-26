# Theme "GW2 UI" : dessin original dans l'esprit des bulles de GW2 UI (bande bleu nuit
# brossee, bord du haut adouci, filet clair en bas). Aucune image de GW2 UI n'est reprise.
# Lancer depuis le dossier de l'addon : python3 tools/gw2.py
import numpy as np
from PIL import Image, ImageDraw, ImageOps
from scipy.ndimage import gaussian_filter
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
src = open(os.path.join(os.path.dirname(__file__), "pills2.py")).read().split("SUF={")[0]
exec(src)  # shape / render / sdf

NAVY = np.array((0.10, 0.165, 0.25))
NAVY_SEL = np.array((0.15, 0.24, 0.36))
LINE = np.array((0.90, 0.92, 0.95))
GOLD = (1.0, 0.82, 0.42)


def brush(H, W, seed):
    # Coups de pinceau horizontaux : bruit etire en largeur.
    r = np.random.default_rng(seed)
    n = gaussian_filter(r.random((H, W)), (0.8, 6))
    return (n - n.min()) / (n.max() - n.min())


def save(rgb, a, name):
    Image.fromarray((np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)]) * 255).round().astype(np.uint8), "RGBA").save(name)


# Bulle 64x64 (9 morceaux de 16) ---------------------------------------------------------
S = 64
y = np.arange(S)[:, None] * np.ones((1, S))
x = np.ones((S, 1)) * np.arange(S)[None, :]
b = brush(S, S, 7)
rgb = NAVY * (0.85 + 0.30 * b[..., None])
rgb = rgb * (1 + 0.10 * (1 - y / S))[..., None]           # un peu plus clair en haut
a = np.full((S, S), 0.93)
# Haut adouci et un peu dechire ; cotes adoucis.
rag = gaussian_filter(np.random.default_rng(11).random(S), 1.5)
rag = (rag - rag.min()) / (rag.max() - rag.min())
top = np.clip((y - (1.0 + 2.5 * rag[None, :])) / 4.0, 0, 1)
side = np.clip(np.minimum(x, S - 1 - x) / 3.0, 0, 1)
a = a * top * side
# Filet clair en bas (lignes 61-62), ombre fine dessous (ligne 63).
line = np.zeros((S, S))
line[61, :] = 1.0
line[62, :] = 0.55
line = line * side
rgb = rgb * (1 - line[..., None]) + LINE * line[..., None]
a = np.maximum(a, line)
a[63, :] = 0.25 * side[63, :]
rgb[63, :] = 0.05
save(rgb, a, "BubbleGw2.png")

# Pointe 32x32 : meme bleu, bords clairs dans le prolongement du filet (colonnes 10 et 22).
T, SS = 32, 4
m = Image.new("L", (T * SS, T * SS), 0)
ImageDraw.Draw(m).polygon([(10 * SS, 0), (22 * SS, 0), (13 * SS, 22 * SS)], fill=255)
tm = np.asarray(m.resize((T, T), Image.LANCZOS), float) / 255
l = Image.new("L", (T * SS, T * SS), 0)
ImageDraw.Draw(l).line([(10 * SS, 9 * SS), (13 * SS, 22 * SS), (22 * SS, 9 * SS)], fill=255, width=int(1.6 * SS), joint="curve")
lm = np.asarray(l.resize((T, T), Image.LANCZOS), float) / 255
tb = brush(T, T, 3)
trgb = NAVY * (0.85 + 0.30 * tb[..., None])
ta = tm * 0.93
trgb = trgb * (1 - lm[..., None]) + LINE * lm[..., None]
ta = np.maximum(ta, lm)
save(trgb, ta, "BubbleGw2Tail.png")

# Choix de la roue (pilules) ---------------------------------------------------------------
def fill(base, seed):
    def f(yy, W, H):
        n = brush(H, W, seed)
        return base * (0.85 + 0.30 * n[..., None]) * (1 + 0.12 * (1 - yy[..., None]))
    return f

SUF = {"none": "", "down": "TailDown", "left": "Tail"}
for v in ("none", "down", "left"):
    render(v, fill(NAVY, 5), lambda yy: 0.92 + 0 * yy, tuple(LINE), 0.30, 1.0, name=f"PillGw2{SUF[v]}.png")
    render(v, fill(NAVY_SEL, 6), lambda yy: 0.95 + 0 * yy, tuple(LINE), 0.95, 1.3, ((0.55, 0.72, 1.0), 0.45), name=f"PillGw2Sel{SUF[v]}.png")
for base in ("PillGw2", "PillGw2Sel"):
    for suf in ("Tail", "TailDown"):
        ImageOps.mirror(Image.open(f"{base}{suf}.png")).save(f"{base}{suf}R.png")

# Vignette des options -----------------------------------------------------------------------
exec(open(os.path.join(os.path.dirname(__file__), "thumbs.py")).read().split("out={")[0].replace('A="./"', 'A="./"'))
im = bgimg()
B = Image.open("BubbleGw2.png").convert("RGBA")
im.alpha_composite(nine(B, 150, 48, (16, 16, 16, 16)), (10, 8))
t = Image.open("BubbleGw2Tail.png").convert("RGBA").resize((22, 22), Image.LANCZOS)
im.alpha_composite(t, (64, 49))
d = ImageDraw.Draw(im)
d.rounded_rectangle((24, 22, 120, 27), 2, fill=(240, 242, 246, 255))
d.rounded_rectangle((24, 33, 94, 37), 2, fill=(240, 242, 246, 255))
P = Image.open("PillGw2SelTailDown.png").convert("RGBA")
im.alpha_composite(nine(P, 132, 39, (26, 14, 14, 23)), (118, 70))
d = ImageDraw.Draw(im)
d.rounded_rectangle((150, 82, 224, 87), 2, fill=tuple(int(c * 255) for c in GOLD) + (255,))
im.save("Thumbs/Gw2.png")
print("ok")
