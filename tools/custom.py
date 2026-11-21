# Theme "Personnalise" : chaque image en deux calques blancs (remplissage et contour), teintes
# en jeu par les couleurs choisies (SetVertexColor).
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter
exec(open('tools/pills2.py').read().split("rng=np.random")[0])
def save(rgb_l, a, name, mirror=False):
    im = Image.fromarray((np.dstack([np.ones(a.shape + (3,)) * rgb_l[..., None], np.clip(a, 0, 1)]) * 255).round().astype(np.uint8), 'RGBA')
    if mirror: im = im.transpose(Image.FLIP_LEFT_RIGHT)
    im.save(name)
def layers(variant):
    d, W, H, ox = shape(variant)
    def down(x): return np.asarray(Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS), np.float32) / 255
    fill = down(np.clip(0.5 - d, 0, 1))
    def edge(bw): return down(np.clip(1 - np.abs(d + bw / 2) / (bw / 2 + 0.5), 0, 1) ** 1.2 * (d < 0.5))
    yy = np.linspace(0, 1, H)[:, None] * np.ones((1, W))
    return fill, edge(1.0), edge(1.4), yy
SUF = {"none": "", "down": "TailDown", "left": "Tail"}
for v in ("none", "down", "left"):
    fill, e1, e2, yy = layers(v)
    shade = 1 - 0.22 * yy                     # un peu plus sombre en bas, comme les autres themes
    glow = np.clip(gaussian_filter(e2, 2.0) * 1.8, 0, 1) * 0.55
    sel = np.maximum(e2, glow)
    for mirror in ([False, True] if v != "none" else [False]):
        r = "R" if mirror else ""
        save(shade, fill, f"PillCustomFill{SUF[v]}{r}.png", mirror)
        save(np.ones_like(yy), e1, f"PillCustomEdge{SUF[v]}{r}.png", mirror)
        save(np.ones_like(yy), sel, f"PillCustomSelEdge{SUF[v]}{r}.png", mirror)
# Bulle (64x64, decoupe 16) et pointe (32x32), memes formes que les autres bulles.
SS4 = 4
def rr(W, H, box, r):
    im = Image.new('L', (W * SS4, H * SS4), 0); ImageDraw.Draw(im).rounded_rectangle([v * SS4 for v in box], radius=r * SS4, fill=255)
    return np.asarray(im.resize((W, H), Image.LANCZOS), float) / 255
S = 64
outer = rr(S, S, (1, 1, S - 1, S - 1), 12); inner = rr(S, S, (3, 3, S - 3, S - 3), 10)
y = np.linspace(0, 1, S)[:, None] * np.ones((1, S))
save(1 - 0.22 * y, outer, "BubbleCustomFill.png")
save(np.ones_like(y), np.clip(outer - inner, 0, 1), "BubbleCustomEdge.png")
T = 32
m = Image.new('L', (T * SS4, T * SS4), 0); ImageDraw.Draw(m).polygon([(10 * SS4, 0), (22 * SS4, 0), (13 * SS4, 22 * SS4)], fill=255)
tm = np.asarray(m.resize((T, T), Image.LANCZOS), float) / 255
l = Image.new('L', (T * SS4, T * SS4), 0); ImageDraw.Draw(l).line([(10 * SS4, 9 * SS4), (13 * SS4, 22 * SS4), (22 * SS4, 9 * SS4)], fill=255, width=2 * SS4, joint="curve")
lm = np.asarray(l.resize((T, T), Image.LANCZOS), float) / 255
# la pointe reprend la teinte du bas de la bulle
save(np.ones((T, T)) * (1 - 0.22 * 0.92), tm, "BubbleCustomFillTail.png")
save(np.ones((T, T)), lm, "BubbleCustomEdgeTail.png")
print("ok")
