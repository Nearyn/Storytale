import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter
exec(open('pills2.py').read().split("SUF={")[0])   # reprend shape/render/sdf de pills2.py
FILL=(0.15,0.06,0.18); FILLSEL=(0.22,0.09,0.26); PINK=(0.87,0.56,0.93); PINKSEL=(1.0,0.68,1.0)
wf=lambda y,W,H: np.array(FILL)*(1-y[...,None]*0.3)+np.array(FILL)*0.7*y[...,None]
ws=lambda y,W,H: np.array(FILLSEL)*(1-y[...,None]*0.3)+np.array(FILLSEL)*0.7*y[...,None]
SUF={"none":"","down":"TailDown","left":"Tail"}
for v in ("none","down","left"):
    render(v,wf,lambda y:0.86+0*y,PINK,0.65,1.0,name=f"PillWhisper{SUF[v]}.png")
    render(v,ws,lambda y:0.92+0*y,PINKSEL,1.0,1.6,((0.95,0.5,1.0),0.6),name=f"PillWhisperSel{SUF[v]}.png")
# Bulle au-dessus du PNJ (9-slice 16) + pointe
SS=4; S=64
def rr_mask(W,H,box,r):
    im=Image.new('L',(W*SS,H*SS),0); ImageDraw.Draw(im).rounded_rectangle([v*SS for v in box],radius=r*SS,fill=255)
    return np.asarray(im.resize((W,H),Image.LANCZOS),float)/255
outer=rr_mask(S,S,(1,1,S-1,S-1),12); inner=rr_mask(S,S,(3,3,S-3,S-3),10)
border=np.clip(outer-inner,0,1); fill=inner
rgb=np.zeros((S,S,3)); a=np.zeros((S,S))
fa=fill*0.9; rgb=np.array(FILL)*np.ones((S,S,3)); a=fa
rgb=rgb*(1-border[...,None])+np.array(PINK)*border[...,None]; a=np.maximum(a,border)
Image.fromarray((np.dstack([rgb,a])*255).astype(np.uint8),'RGBA').save("BubbleWhisper.png")
T=32
m=Image.new('L',(T*SS,T*SS),0); d=ImageDraw.Draw(m); d.polygon([(10*SS,0),(22*SS,0),(13*SS,22*SS)],fill=255)
tm=np.asarray(m.resize((T,T),Image.LANCZOS),float)/255
l=Image.new('L',(T*SS,T*SS),0); d=ImageDraw.Draw(l); d.line([(10*SS,9*SS),(13*SS,22*SS),(22*SS,9*SS)],fill=255,width=2*SS,joint="curve")
lm=np.asarray(l.resize((T,T),Image.LANCZOS),float)/255
rgb=np.array(FILL)*np.ones((T,T,3)); a=tm*0.9
rgb=rgb*(1-lm[...,None])+np.array(PINK)*lm[...,None]; a=np.maximum(a,lm)
Image.fromarray((np.dstack([rgb,a])*255).astype(np.uint8),'RGBA').save("BubbleWhisperTail.png")
# Verre fume : fond sombre translucide, filet dore, reflet en haut
S=64
outer=rr_mask(S,S,(1,1,S-1,S-1),9); inner=rr_mask(S,S,(2.2,2.2,S-2.2,S-2.2),8)
border=np.clip(outer-inner,0,1)
y=np.linspace(0,1,S)[:,None]*np.ones((1,S))
fillc=np.dstack([0.05+0.03*(1-y),0.055+0.03*(1-y),0.07+0.035*(1-y)])
a=inner*(0.60+0.10*y)
hl=np.exp(-((y-0.06)/0.03)**2)*0.10*inner
rgb=fillc+hl[...,None]
rgb=rgb*(1-border[...,None])+np.array((0.90,0.75,0.45))*border[...,None]; a=np.maximum(a,border*0.85)
Image.fromarray((np.dstack([np.clip(rgb,0,1),np.clip(a,0,1)])*255).astype(np.uint8),'RGBA').save("ThemeGlass.png")
print("ok")
