import numpy as np, cv2
from PIL import Image, ImageFilter
from scipy.ndimage import label, gaussian_filter, binary_opening, binary_fill_holes
im=Image.open('reference.png').convert('RGB')
a=np.asarray(im,float); H,W=a.shape[:2]
# 1) marque-page qui depasse en bas : on le retire (inpaint sur la couverture, coupe en dessous)
# eclats dores/jaunes sur le cuir (bords bas et cotes) : fondus dans le cuir voisin.
# Les coins en laiton sont gardes ; les pages ne sont pas touchees.
from scipy.ndimage import binary_dilation
Hh,Ww=a.shape[:2]; YY,XX=np.mgrid[0:Hh,0:Ww]
leatherZone=((YY>995)&(YY<1120)) | (XX<150) | (XX>1880)
corners=((XX<230)|(XX>1790))&((YY<200)|(YY>930))
fleck=(a[...,0]>100)&((a[...,0]-a[...,2])>55)&(a.mean(2)>62)&leatherZone&~corners
fleck=binary_dilation(fleck,iterations=3)
wl=(~fleck).astype(float)
fillc=np.stack([gaussian_filter(a[...,c]*wl,7)/np.maximum(gaussian_filter(wl,7),1e-3) for c in range(3)],-1)
a=np.where(fleck[...,None],fillc,a)
lum=a.mean(2); warm=a[...,0]-a[...,2]
dark=(lum<34)&(warm<14); dark=binary_opening(dark,iterations=2)
lab,n=label(dark)
border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
fg=~np.isin(lab,list(border)); lab2,_=label(fg); sz=np.bincount(lab2.ravel()); sz[0]=0
book=binary_fill_holes(lab2==sz.argmax())
# ce qui pend sous la couverture est coupe en suivant le bas du cuir
for cx in range(800,1200):
    w=1.0-np.clip((abs(cx-1000)-150)/50,0,1)
    if w<=0: continue
    book[1084+int((1-w)*12):,cx]=False
# en haut de la reliure : boucle et attaches retirees (tout ce qui n'est pas du papier au-dessus des pages)
from scipy.ndimage import median_filter
paperish=(lum>105)&((a[...,0]-a[...,2])<120)
cols=np.arange(840,1190); edge=np.zeros(len(cols))
for i,cx in enumerate(cols):
    rows=np.where(paperish[50:170,cx])[0]
    edge[i]=50+(rows[0] if len(rows) else 120)
edge=median_filter(edge,31); edge=gaussian_filter(edge,6)
# ligne de haut des pages attendue : celle des bords de la zone, avec un creux a la reliure
base=np.interp(cols,[cols[0],cols[-1]],[edge[0],edge[-1]])
want=base+55*np.exp(-((cols-1035)/28.0)**2)
for i,cx in enumerate(cols):
    e=int(edge[i]); wnt=int(min(want[i],edge[i]))
    if e>wnt+1:   # papier masque par une attache : on prolonge le papier vers le haut
        src=a[e+4:e+4+(e-wnt),cx][::-1] if e+4+(e-wnt)<a.shape[0] else a[e+4:e+5,cx].repeat(e-wnt,0)
        a[wnt:e,cx]=src[:e-wnt]
    book[:wnt+2,cx]=False
yy,xx=np.mgrid[0:H,0:W]
alpha=np.clip(gaussian_filter(book.astype(float),1.3)*1.15-0.08,0,1)
# 2) interieur des pages nettoye (comme avant)
inner=np.zeros((H,W),bool); inner[175:880,300:1760]=True
innerf=gaussian_filter(inner.astype(float),45)
L=gaussian_filter(lum,2); spots=L<gaussian_filter(L,30)-6; w=(~spots).astype(float)
def nconv(ch,s): return gaussian_filter(ch*w,s)/np.maximum(gaussian_filter(w,s),1e-3)
clean=np.stack([nconv(a[...,c],28) for c in range(3)],-1)
fine=a-np.stack([gaussian_filter(a[...,c],3) for c in range(3)],-1)
target=np.array([238,222,186.])
inside=clean*0.45+target*0.55+fine*0.35
out=a*(1-innerf[...,None])+inside*innerf[...,None]
page=gaussian_filter(((lum>120)&book).astype(float),6)*(1-innerf)
blur=np.stack([gaussian_filter(a[...,c],18) for c in range(3)],-1)
lighter=(a*0.45+blur*0.55)*0.6+target*0.4
out=out*(1-page[...,None])+lighter*page[...,None]
# 3) reliure : plus de trait ni de points, une ombre douce et continue
G=1035+(yy-120)*(1012-1035)/(985-120.0)
gz=np.clip(1-np.abs(xx-G)/70,0,1)**1.2*((yy>95)&(yy<985))
gz=gaussian_filter(gz.astype(float),6)
Lg=gaussian_filter(out.mean(2),1.5); dots=Lg<gaussian_filter(Lg,12)-5
wd=(~dots).astype(float)
fill=np.stack([gaussian_filter(out[...,c]*wd,5)/np.maximum(gaussian_filter(wd,5),1e-3) for c in range(3)],-1)
nod=np.where(dots[...,None],fill,out)
shadow=np.exp(-((xx-G)/30.0)**2)[...,None]*np.array([0.14,0.17,0.21])
crease=np.exp(-((xx-G)/2.2)**2)[...,None]*np.array([0.20,0.24,0.30])
gut=nod*(1-shadow)*(1-crease)
out=out*(1-gz[...,None])+gut*gz[...,None]
rgba=np.dstack([np.clip(out,0,255)/255,alpha])
img=Image.fromarray((rgba*255).astype(np.uint8),'RGBA')
img.save('/tmp/book_full.png')
sp=img.resize((1024,576),Image.LANCZOS)
c=Image.new('RGBA',(1024,1024),(0,0,0,0)); c.paste(sp,(0,0)); c.save('./BookSpread.png')
chk=Image.new('RGBA',(1024,576),(60,40,25,255)); chk.alpha_composite(sp)
chk.resize((640,360)).save('/tmp/bk.png'); chk.crop((420,40,620,560)).save('/tmp/gut.png')
