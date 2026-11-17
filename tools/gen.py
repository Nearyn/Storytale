import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter
A="./"
exec(open('pills2.py').read().split("SUF={")[0])
SS=4
def rr_mask(W,H,box,r):
    im=Image.new('L',(W*SS,H*SS),0); ImageDraw.Draw(im).rounded_rectangle([v*SS for v in box],radius=r*SS,fill=255)
    return np.asarray(im.resize((W,H),Image.LANCZOS),float)/255
def crop_src(path,box):
    im=Image.open(A+path).convert("RGBA"); W,H=im.size
    return im.crop(tuple(int(v*s) for v,s in zip(box,(W,H,W,H)))).convert("RGB")
def sampler(img):
    def f(y,W,H):
        return np.asarray(img.resize((W,H),Image.LANCZOS),float)/255
    return f
def flat(c,dk=0.3):
    return lambda y,W,H: np.array(c)*(1-y[...,None]*dk)+np.array(c)*(1-dk)*y[...,None]*0
# Themes : (cle, remplissage, alpha, bordure, alpha bordure, bordure choix, lueur choix, texte, encre?, doux?)
SPECS={
 "Veil":   dict(fill=flat((0.07,0.07,0.09),0.35),a=0.84,b=(0.45,0.45,0.50),ba=0.9,sb=(1,0.85,0.25),glow=(1,0.78,0.2)),
 "Glass":  dict(fill=flat((0.07,0.08,0.10),0.3),a=0.66,b=(0.90,0.75,0.45),ba=0.85,sb=(1,0.86,0.55),glow=(0.95,0.75,0.35)),
 "Halo":   dict(fill=flat((0.0,0.0,0.0),0),a=0.58,b=(0,0,0),ba=0.0,sb=(1,0.84,0.35),glow=(1,0.8,0.3),soft=True),
 "Ink":    dict(fill=flat((0.04,0.035,0.03),0.2),a=0.70,b=(0.83,0.67,0.31),ba=0.75,sb=(1,0.84,0.47),glow=(0.95,0.75,0.3)),
 "Velin":  dict(src=("ThemeVelin.png",(0.35,0.35,0.65,0.65)),a=0.97,b=(0.66,0.48,0.16),ba=1,sb=(0.85,0.62,0.15),glow=(0.95,0.72,0.22)),
 "Arcane": dict(src=("ThemeArcane.png",(0.35,0.35,0.65,0.65)),a=0.97,b=(0.28,0.40,0.75),ba=1,sb=(0.40,0.58,1.0),glow=(0.45,0.65,1.0)),
 "Sylvan": dict(src=("ThemeSylvan.png",(0.35,0.35,0.65,0.65)),a=0.97,b=(0.33,0.43,0.14),ba=1,sb=(0.48,0.62,0.18),glow=(0.6,0.8,0.25)),
 "Starry": dict(src=("ThemeStarry.png",(0.35,0.35,0.65,0.65)),a=0.95,b=(0.85,0.68,0.30),ba=1,sb=(1,0.84,0.43),glow=(1,0.8,0.35)),
 "Parch":  dict(src=("Parchment.png",(0.3,0.3,0.7,0.7)),a=0.97,b=(0.40,0.25,0.10),ba=0.9,sb=(0.72,0.50,0.12),glow=(0.95,0.72,0.22)),
 "ParchDark": dict(src=("themes.tga",(0.62,0.35,0.86,0.65)),a=0.95,b=(0.58,0.60,0.66),ba=0.9,sb=(1,0.85,0.25),glow=(1,0.78,0.2)),
 "DUIBrown": dict(src=("ParchmentDUIBrown.png",(0.35,0.12,0.65,0.30)),a=0.97,b=(0.38,0.24,0.11),ba=0.9,sb=(0.72,0.50,0.12),glow=(0.95,0.72,0.22)),
 "DUIDark":  dict(src=("ParchmentDUIDark.png",(0.35,0.12,0.65,0.30)),a=0.95,b=(0.62,0.62,0.68),ba=0.9,sb=(1,0.85,0.25),glow=(1,0.78,0.2)),
}
SUF={"none":"","down":"TailDown","left":"Tail"}
def lighten(img,k): return Image.eval(img,lambda v:min(255,int(v*k)))
for key,s in SPECS.items():
    if "src" in s:
        img=crop_src(*s["src"]); fill=sampler(img); fsel=sampler(lighten(img,1.06))
    else:
        fill=s["fill"]; fsel=s["fill"]
    a=s["a"]
    for v in ("none","down","left"):
        if s.get("soft"):
            # halo : bord flou sans contour
            d,W,H,ox=shape(v)
            def soft(alpha,name,sel):
                m=np.clip(0.5-d,0,1); m=np.asarray(Image.fromarray((m*255).astype(np.uint8)).resize((W,H),Image.LANCZOS),float)/255
                m=gaussian_filter(m,2.2)*alpha
                rgb=np.zeros((H,W,3))
                if sel:
                    bd=np.clip(1-np.abs(d+0.8)/1.3,0,1)*(d<0.5); bd=np.asarray(Image.fromarray((bd*255).astype(np.uint8)).resize((W,H),Image.LANCZOS),float)/255*0.6
                    rgb=rgb*(1-bd[...,None])+np.array(s["sb"])*bd[...,None]; m=np.maximum(m,bd)
                Image.fromarray((np.dstack([rgb,np.clip(m,0,1)])*255).astype(np.uint8),'RGBA').save(A+f"Pill{key}{'Sel' if sel else ''}{SUF[v]}.png")
            soft(a,"",False); soft(a+0.12,"",True)
        else:
            render(v,fill,lambda y,a=a:a+0*y,s["b"],s["ba"],1.0,name=A+f"Pill{key}{SUF[v]}.png")
            render(v,fsel,lambda y,a=a:min(1,a+0.06)+0*y,s["sb"],1.0,1.6,(s["glow"],0.55),name=A+f"Pill{key}Sel{SUF[v]}.png")
    # Bulle au-dessus du PNJ (64x64, decoupe 16) + pointe 32x32 (meme dessin que Murmure)
    S=64
    outer=rr_mask(S,S,(1,1,S-1,S-1),12); inner=rr_mask(S,S,(3,3,S-3,S-3),10)
    border=np.clip(outer-inner,0,1)*s["ba"]
    y=np.linspace(0,1,S)[:,None]*np.ones((1,S))
    rgb=fill(y,S,S) if "src" in s else fill(y,S,S)
    al=(outer if s["ba"]==0 else inner)*a
    if s.get("soft"): al=gaussian_filter(rr_mask(S,S,(4,4,S-4,S-4),10),2.5)*a
    rgb=rgb*(1-border[...,None])+np.array(s["b"])*border[...,None]; al=np.maximum(al,border)
    Image.fromarray((np.dstack([np.clip(rgb,0,1),np.clip(al,0,1)])*255).astype(np.uint8),'RGBA').save(A+f"Bubble{key}.png")
    T=32
    m=Image.new('L',(T*SS,T*SS),0); dd=ImageDraw.Draw(m); dd.polygon([(10*SS,0),(22*SS,0),(13*SS,22*SS)],fill=255)
    tm=np.asarray(m.resize((T,T),Image.LANCZOS),float)/255
    l=Image.new('L',(T*SS,T*SS),0); dd=ImageDraw.Draw(l); dd.line([(10*SS,9*SS),(13*SS,22*SS),(22*SS,9*SS)],fill=255,width=2*SS,joint="curve")
    lm=np.asarray(l.resize((T,T),Image.LANCZOS),float)/255*s["ba"]
    yy=np.linspace(0,1,T)[:,None]*np.ones((1,T))
    # pointe : couleur moyenne du bas de la bulle
    base=rgb[S-8:S-4,24:40].reshape(-1,3).mean(0)
    trgb=np.ones((T,T,3))*base; ta=tm*a
    if s.get("soft"): ta=gaussian_filter(tm,1.2)*a
    trgb=trgb*(1-lm[...,None])+np.array(s["b"])*lm[...,None]; ta=np.maximum(ta,lm)
    Image.fromarray((np.dstack([np.clip(trgb,0,1),np.clip(ta,0,1)])*255).astype(np.uint8),'RGBA').save(A+f"Bubble{key}Tail.png")
print("ok")
