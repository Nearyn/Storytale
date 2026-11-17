import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt, gaussian_filter
SS=4; BW,BH=64,64; INSET=3; R=9; TW=12; TH=9
def sdf(mask):
    inside=distance_transform_edt(mask); outside=distance_transform_edt(~mask)
    return (outside-inside)/SS
def smin(a,b,k):
    h=np.clip(0.5+0.5*(b-a)/k,0,1); return b*(1-h)+a*h-k*h*(1-h)
def bez(p0,c,p1,n=40):
    t=np.linspace(0,1,n)[:,None]; p0,c,p1=map(np.array,(p0,c,p1)); return [tuple(v) for v in (1-t)**2*p0+2*(1-t)*t*c+t*t*p1]
def shape(variant):
    if variant=="down": W,H,ox=BW+TW,BH+TH,TW
    elif variant=="left": W,H,ox=BW+TW,BH,TW
    else: W,H,ox=BW,BH,0
    body=Image.new('L',(W*SS,H*SS),0)
    ImageDraw.Draw(body).rounded_rectangle([(ox+INSET)*SS,INSET*SS,(ox+BW-INSET)*SS-1,(BH-INSET)*SS-1],radius=R*SS,fill=255)
    d=sdf(np.asarray(body)>127)
    if variant!="none":
        tail=Image.new('L',(W*SS,H*SS),0); dr=ImageDraw.Draw(tail)
        L=ox+INSET  # bord gauche du corps
        if variant=="down":
            b=BH-INSET   # bas du corps
            top=(L+5,b-15); bot=(L+9,b-1); tip=(2.5,H-2.5)
            pts=bez(top,(L-3,b-6),tip)+bez(tip,(L-1,b+1),bot)[1:]+[(L+9,b-15)]
        else:
            y0=22
            top=(L+5,y0-7); bot=(L+5,y0+7); tip=(1.5,y0-3)
            pts=bez(top,(L-3,y0-6),tip)+bez(tip,(L-3,y0+3),bot)[1:]
        dr.polygon([(x*SS,y*SS) for x,y in pts],fill=255)
        dt=sdf(np.asarray(tail)>127)
        d=smin(d,dt,2.5)
    return d,W,H,ox
def render(variant,fill_fn,fill_a,border_rgb,border_a,bw,glow=None,seed=1,name=""):
    d,W,H,ox=shape(variant)
    fill=np.clip(0.5-d,0,1)                      # d en pixels finaux
    border=np.clip(0.5-np.abs(d+bw/2)+bw/2-0.0,0,1)*np.clip(0.5-d,0,1)
    border=np.clip(1-np.abs(d+bw/2)/(bw/2+0.5),0,1)**1.2*(d<0.5)
    def down(a): return np.asarray(Image.fromarray((np.clip(a,0,1)*255).astype(np.uint8)).resize((W,H),Image.LANCZOS),np.float32)/255
    fill,border=down(fill),down(border)
    yy=np.linspace(0,1,H)[:,None]*np.ones((1,W))
    rgb=np.zeros((H,W,3)); a=np.zeros((H,W))
    if glow:
        g=gaussian_filter(border,2.0); g=np.clip(g*1.8,0,1)*glow[1]
        rgb=rgb*(1-g[...,None])+np.array(glow[0])*g[...,None]; a=np.maximum(a,g)
    fa=fill*fill_a(yy); frgb=fill_fn(yy,W,H)
    rgb=rgb*(1-fa[...,None])+frgb*fa[...,None]; a=fa+a*(1-fa)
    b=border*border_a
    rgb=rgb*(1-b[...,None])+np.array(border_rgb)*b[...,None]; a=b+a*(1-b)
    Image.fromarray((np.dstack([np.clip(rgb,0,1),np.clip(a,0,1)])*255).round().astype(np.uint8),'RGBA').save(name)
rng=np.random.default_rng(3)
def paperN(W,H): return (lambda n:(n-n.min())/(n.max()-n.min()))(gaussian_filter(np.random.default_rng(5).random((H,W)),3))
dark=lambda y,W,H: np.array([0.09,0.09,0.10])*(1-y[...,None])+np.array([0.04,0.04,0.05])*y[...,None]
dsel=lambda y,W,H: np.array([0.17,0.15,0.10])*(1-y[...,None])+np.array([0.08,0.07,0.05])*y[...,None]
def pfill(light):
    def f(y,W,H):
        p=paperN(W,H); c0=np.array([0.90,0.80,0.62])*light; c1=np.array([0.80,0.66,0.45])*light
        t=(np.clip((p-0.5)*1.4+0.5,0,1)*0.5+y*0.25)[...,None]; return c0*(1-t)+c1*t
    return f
SUF={"none":"","down":"TailDown","left":"Tail"}
for v in ("none","down","left"):
    render(v,dark,lambda y:0.78-0.12*y,(1,1,1),0.14,1.0,name=f"PillDark{SUF[v]}.png")
    render(v,dsel,lambda y:0.88-0.1*y,(1.0,0.84,0.35),0.95,1.4,((1.0,0.78,0.25),0.55),name=f"PillDarkSel{SUF[v]}.png")
    render(v,pfill(0.97),lambda y:0.96+0*y,(0.30,0.18,0.08),0.75,1.0,name=f"PillFantasy{SUF[v]}.png")
    render(v,pfill(1.04),lambda y:0.98+0*y,(0.72,0.50,0.12),1.0,1.6,((0.95,0.72,0.22),0.6),name=f"PillFantasySel{SUF[v]}.png")
print("ok")
