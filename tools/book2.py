import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
A="./"
S=256; C=15
rng=np.random.default_rng(11)
def nz(s): n=gaussian_filter(rng.random((S,S)),s); return (n-n.min())/(n.max()-n.min())
n1,n2,n3,n4=nz(1.2),nz(4),nz(14),nz(30)
y,x=np.mgrid[0:S,0:S].astype(float)
def page(outer_left=True):
    xo = x if outer_left else (S-1-x)
    inner = (S-1-x) if outer_left else x
    # parchemin vieilli : jaune-brun, taches et rousseurs
    base=np.dstack([0.86,0.76,0.56])*np.ones((S,S,3))
    tone=(n3-0.5)*0.16+(n4-0.5)*0.12+(n1-0.5)*0.05
    rgb=base*(1+tone[...,None])
    stain=np.clip((n4-0.62)*3,0,1)*0.18
    rgb=rgb*(1-stain[...,None]*np.array([0.2,0.45,0.8]))
    fox=gaussian_filter((rng.random((S,S))>0.99975).astype(float),2.4)*30
    rgb=rgb*(1-np.clip(fox,0,0.22)[...,None]*np.array([0.3,0.55,0.9]))
    # bords brunis
    d=np.minimum.reduce([xo-C,y-C,S-1-C-y])
    burn=np.clip(1-d/26,0,1)**1.6*(0.45+0.25*n2)
    rgb=rgb*(1-burn[...,None]*np.array([0.45,0.6,0.8]))
    # tranche des pages
    stack=((xo>=C)&(xo<C+5))|((y>=C)&(y<C+3))|((y<=S-1-C)&(y>S-1-C-3))
    rgb[stack]=rgb[stack]*(0.78+0.12*(np.sin(xo*2.6)[stack,None]*0.5+0.5))
    # reliure
    g=np.clip(1-inner/52,0,1)**1.7
    rgb=rgb*(1-0.55*g[...,None])
    # cuir rouge-brun avec grain, filet dore double
    leather=np.dstack([0.30+0.08*n1+0.05*n2,0.12+0.04*n1,0.07+0.03*n1])
    cover=(xo<C)|(y<C)|(y>S-1-C)
    rgb[cover]=leather[cover]
    for k in (3,6):
        gl=((xo==k)&(y>=k)&(y<=S-1-k))|((y==k)|(y==S-1-k))&(xo>=k)
        rgb[gl&cover]=np.array([0.78,0.60,0.24])
    # coins en laiton (cote exterieur)
    for cy in (0,S-1):
        dy=np.abs(y-cy)
        tri=(xo+dy<22)
        br=np.dstack([0.72,0.55,0.22])*(0.75+0.35*n2[...,None])
        edge=(np.abs(xo+dy-21)<1.2)
        rgb[tri]=br[tri]; rgb[edge&tri]=np.array([0.35,0.24,0.08])
        rivet=np.hypot(xo-6,dy-6)<2.2
        rgb[rivet]=np.array([0.95,0.85,0.55])
    # signet rouge sur la page de droite, pres de la reliure
    if not outer_left:
        rb=(x>=31)&(x<36)&(y>=C)
        shade=0.75+0.25*np.cos((x-34)/4*1.5)
        rgb[rb]=(rgb*0.35+np.array([0.42,0.07,0.06])*shade[...,None]*0.65)[rb]
    a=np.ones((S,S))
    img=np.dstack([np.clip(rgb,0,1),a])
    return Image.fromarray((img*255).astype(np.uint8),"RGBA")
page(True).save(A+"BookLeft.png"); page(False).save(A+"BookRight.png")
sp=Image.new("RGBA",(S*2,S)); sp.paste(Image.open(A+"BookLeft.png"),(0,0)); sp.paste(Image.open(A+"BookRight.png"),(S,0)); sp.save("/tmp/book2.png")
