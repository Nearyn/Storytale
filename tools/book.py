import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
A="./"
S=256
rng=np.random.default_rng(7)
n=gaussian_filter(rng.random((S,S)),3); n=(n-n.min())/(n.max()-n.min())
n2=gaussian_filter(rng.random((S,S)),12); n2=(n2-n2.min())/(n2.max()-n2.min())
y,x=np.mgrid[0:S,0:S].astype(float)
paper=np.dstack([0.93-0.06*n2+0.03*n,0.86-0.07*n2+0.03*n,0.70-0.08*n2+0.03*n])
# cuir de la couverture (bord exterieur, haut, bas)
leather=np.dstack([0.32+0.06*n,0.17+0.04*n,0.08+0.03*n])
C=12  # epaisseur couverture visible
def page(outer_left=True):
    xo = x if outer_left else (S-1-x)          # distance au bord exterieur
    inner = (S-1-x) if outer_left else x       # distance a la reliure
    cover = (xo<C)|(y<C)|(y>S-1-C)
    rgb=paper.copy()
    # tranche des pages (lignes fines pres du bord exterieur, haut et bas)
    stack=((xo>=C)&(xo<C+6))|((y>=C)&(y<C+4))|((y<=S-1-C)&(y>S-1-C-4))
    lines=(np.sin(xo*2.2)*0.5+0.5)*0.10
    rgb[stack]=rgb[stack]*(0.88+lines[stack,None])
    # ombre de la reliure
    g=np.clip(1-inner/46,0,1)**1.8
    rgb=rgb*(1-0.45*g[...,None])
    # leger assombrissement vers les bords
    e=np.clip(1-np.minimum(xo-C,np.minimum(y-C,S-1-C-y))/30,0,1)*0.12
    rgb=rgb*(1-e[...,None])
    rgb[cover]=leather[cover]
    # filet dore sur la couverture
    gold=((xo==C-4)|(y==C-4)|(y==S-1-C+4))&~((xo<C-4)|(y<C-4)|(y>S-1-C+4))
    rgb[gold]=np.array([0.80,0.62,0.25])
    a=np.ones((S,S))
    # coins arrondis de la couverture (cote exterieur)
    r=10
    for cy in (r, S-1-r):
        m=(xo<r)&(np.abs(y-cy)<=r)&(((y<r)&(cy==r))|((y>S-1-r)&(cy==S-1-r)))
        d=np.hypot(xo-r,y-cy); a[m&(d>r)]=0
    img=np.dstack([np.clip(rgb,0,1),a])
    return Image.fromarray((img*255).astype(np.uint8),"RGBA")
page(True).save(A+"BookLeft.png"); page(False).save(A+"BookRight.png")
sp=Image.new("RGBA",(S*2,S)); sp.paste(Image.open(A+"BookLeft.png"),(0,0)); sp.paste(Image.open(A+"BookRight.png"),(S,0)); sp.save("/tmp/book.png")
