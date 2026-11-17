exec(open("thumbs.py").read().split("out={")[0])
import numpy as np
from PIL import ImageDraw
INK={"Velin","Arcane","Sylvan","Parch","DUIBrown"}
TXT={"Veil":(0.95,0.92,0.85),"Glass":(0.94,0.92,0.88),"Halo":(0.95,0.93,0.89),"Ink":(0.96,0.93,0.84),"Velin":(0.17,0.10,0.04),"Arcane":(0.16,0.13,0.12),"Sylvan":(0.16,0.12,0.05),"Starry":(0.92,0.89,0.84),"Parch":(0.13,0.08,0.03),"ParchDark":(0.95,0.92,0.85),"DUIBrown":(0.10,0.05,0.02),"DUIDark":(0.95,0.92,0.85)}
MAP={"Veil":"Dark","Glass":"Glass","Halo":"Halo","Ink":"Ink","Velin":"Velin","Arcane":"Arcane","Sylvan":"Sylvan","Starry":"Starry","Parch":"Parchment","ParchDark":"ParchmentDark","DUIBrown":"DUIBrown","DUIDark":"DUIDark"}
sheet=Image.new("RGBA",(4*262,3*134),(20,20,20,255))
for k,(art,th) in enumerate(MAP.items()):
    im=bgimg(); B=Image.open(A+f"Bubble{art}.png").convert("RGBA")
    im.alpha_composite(nine(B,150,48,(16,)*4),(10,8))
    im.alpha_composite(Image.open(A+f"Bubble{art}Tail.png").convert("RGBA").resize((22,22)),(62,48))
    d=ImageDraw.Draw(im); ink=tuple(int(v*255) for v in TXT[art])+(255,)
    d.rounded_rectangle((24,22,120,27),2,fill=ink); d.rounded_rectangle((24,33,94,37),2,fill=ink)
    P=Image.open(A+f"Pill{art}SelTailDown.png").convert("RGBA"); im.alpha_composite(nine(P,132,39,(26,14,14,23)),(118,70))
    d=ImageDraw.Draw(im); sel=(140,51,0,255) if art in INK else (255,224,40,255)
    d.rounded_rectangle((150,82,224,87),2,fill=sel)
    im.save(A+f"Thumbs/{th}Bubble.png"); sheet.alpha_composite(im,((k%4)*262,(k//4)*134))
sheet.save("/tmp/bthumbs.png")
