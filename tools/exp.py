import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter
exec(open("thumbs.py").read().split("out={")[0])
A="./"
# Halo : tache d'ombre douce, 128x128, découpe 48 (bords qui s'estompent, centre uni)
S=128; m=48
a=np.zeros((S,S)); a[m-14:S-m+14,m-14:S-m+14]=1
a=gaussian_filter(a,13); a=a/a.max()*0.62
img=np.dstack([np.zeros((S,S))]*3+[a])
Image.fromarray((img*255).astype(np.uint8),"RGBA").save(A+"ThemeHalo.png")
# Encre et or : 128x64, ombre plus forte à gauche, filet doré dans la marge gauche
Wt,Ht=128,64; L,T=24,20
y=np.arange(Ht)[:,None]; x=np.arange(Wt)[None,:]
fy=np.clip(np.minimum(y,Ht-1-y)/T,0,1); fy=fy*fy*(3-2*fy)
fx=np.clip((Wt-1-x)/L,0,1); fx=fx*fx*(3-2*fx)
grad=0.55-0.30*np.clip((x-L)/(Wt-2*L),0,1)
al=np.clip(fy*fx*grad,0,1)*np.clip((x+6)/12,0,1)
rgb=np.zeros((Ht,Wt,3))
# filet doré : x 8..10, plein au centre, estompé en haut/bas
bar=(x>=8)&(x<=10)
ba=np.clip(np.minimum(y-4,Ht-5-y)/10,0,1)*bar
gold=np.array([0.83,0.67,0.31])
rgb=rgb*(1-ba[...,None])+gold*ba[...,None]
al=np.maximum(al,ba*0.95)
Image.fromarray((np.dstack([rgb,al])*255).clip(0,255).astype(np.uint8),"RGBA").save(A+"ThemeInk.png")

def halo_thumb():
    im=bgimg(); H_=Image.open(A+"ThemeHalo.png").convert("RGBA")
    im.alpha_composite(nine(H_,W-20,H-30,(48,48,48,48)),(10,15))
    bars(im,40,44,(255,214,70,255),(240,236,228,255),shadow=True); return im
def ink_thumb():
    im=bgimg(); I=Image.open(A+"ThemeInk.png").convert("RGBA")
    im.alpha_composite(nine(I,W-40,H-40,(24,20,24,20)),(20,20))
    bars(im,58,46,(255,214,120,255),(245,236,215,255),shadow=True); return im
def cinema_thumb():
    im=bgimg(); d=ImageDraw.Draw(im)
    d.rectangle((0,0,W,22),fill=(0,0,0,255)); d.rectangle((0,H-34,W,H),fill=(0,0,0,255))
    d.rounded_rectangle((W//2-30,H-29,W//2+30,H-25),2,fill=(200,160,80,255))
    d.rounded_rectangle((W//2-70,H-18,W//2+70,H-13),2,fill=(240,232,210,255))
    d.rounded_rectangle((150,44,215,49),2,fill=(255,214,90,255)); d.rounded_rectangle((150,58,200,62),2,fill=(225,220,210,255))
    d.rounded_rectangle((150,70,205,74),2,fill=(225,220,210,255)); return im
halo_thumb().save(A+"Thumbs/Halo.png"); ink_thumb().save(A+"Thumbs/Ink.png"); cinema_thumb().save(A+"Thumbs/Cinema.png")
s=Image.new("RGBA",(3*262,134),(20,20,20,255))
for i,n in enumerate(["Halo","Cinema","Ink"]): s.alpha_composite(Image.open(A+"Thumbs/%s.png"%n),(i*262,0))
s.save("/tmp/t3.png")
