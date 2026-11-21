# Vignettes du theme Personnalise : contour arc-en-ciel (couleurs au choix du joueur).
import numpy as np, colorsys
from PIL import Image, ImageDraw, ImageFilter
exec(open('/tmp/prev_custom.py').read().split("def preview")[0])
def rainbow(W, H):
    x = np.linspace(0, 1, W)[None, :] * np.ones((H, 1))
    rgb = np.zeros((H, W, 3))
    for j in range(W):
        rgb[:, j] = colorsys.hsv_to_rgb(j / W * 0.85, 0.65, 1)
    return rgb
def rainbow_nine(path, W, H, s):
    base = nine(path, W, H, s, (1, 1, 1), 1)
    a = np.asarray(base, float) / 255
    a[..., :3] = rainbow(W, H) * a[..., :3]
    return Image.fromarray((a * 255).round().astype(np.uint8), 'RGBA')
def bars(d, x, y, cols):
    for i, (w, c) in enumerate(cols):
        d.rounded_rectangle((x, y + i * 12, x + w, y + i * 12 + 5), radius=3, fill=c)
bg_dark = Image.open('Thumbs/DarkBubble.png').convert('RGBA').filter(ImageFilter.GaussianBlur(14))
FILL = (0.16, 0.12, 0.30)
# en bulle
t = bg_dark.copy()
t.alpha_composite(nine('BubbleCustomFill.png', 120, 44, 16, FILL, 0.88), (12, 10))
t.alpha_composite(rainbow_nine('BubbleCustomEdge.png', 120, 44, 16), (12, 10))
t.alpha_composite(tint('BubbleCustomFillTail.png', FILL, 0.88), (12 + 52, 10 + 44 - 8))
t.alpha_composite(tint('BubbleCustomEdgeTail.png', (0.55, 0.85, 1), 1), (12 + 52, 10 + 44 - 8))
d = ImageDraw.Draw(t); bars(d, 24, 22, [(96, (245, 240, 250, 255)), (70, (245, 240, 250, 255))])
t.alpha_composite(nine('PillCustomFill.png', 124, 30, 12, FILL, 0.88), (122, 72))
t.alpha_composite(rainbow_nine('PillCustomSelEdge.png', 124, 30, 12), (122, 72))
d = ImageDraw.Draw(t); bars(d, 140, 84, [(86, (255, 140, 210, 255))])
t.save('Thumbs/CustomBubble.png')
# en cadre
t = Image.open('Thumbs/Dark.png').convert('RGBA').filter(ImageFilter.GaussianBlur(14))
t.alpha_composite(nine('BubbleCustomFill.png', 228, 100, 10, FILL, 0.9), (14, 14))
t.alpha_composite(rainbow_nine('BubbleCustomEdge.png', 228, 100, 10), (14, 14))
d = ImageDraw.Draw(t); bars(d, 32, 36, [(78, (255, 140, 210, 255)), (118, (245, 240, 250, 255)), (96, (245, 240, 250, 255))])
t.save('Thumbs/Custom.png')
print("ok")
