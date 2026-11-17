import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter
A="./"
W,H=256,128
def bgimg():
    r=np.random.default_rng(4); n=gaussian_filter(r.random((H,W)),10); n=(n-n.min())/(n.max()-n.min())
    y=np.linspace(0,1,H)[:,None]
    c=np.dstack([0.05+0.06*n,0.09+0.10*n*(1-y*0.3),0.05+0.04*n])
    return Image.fromarray((np.dstack([c,np.ones((H,W))])*255).astype(np.uint8),'RGBA')
def nine(T,w,h,m):
    l,t,r,b=m; TW,TH=T.size; out=Image.new("RGBA",(w,h))
    xs=[(0,l,0,l),(l,TW-r,l,w-r),(TW-r,TW,w-r,w)]; ys=[(0,t,0,t),(t,TH-b,t,h-b),(TH-b,TH,h-b,h)]
    for a,b2,c,d in xs:
        for e,f,g,h2 in ys:
            if d>c and h2>g and b2>a and f>e: out.paste(T.crop((a,e,b2,f)).resize((d-c,h2-g),Image.LANCZOS),(c,g))
    return out
def bars(im,x,y,hdr,body,shadow=False,scale=1.0):
    d=ImageDraw.Draw(im)
    rows=[(x,y,int(78*scale),7,hdr),(x,y+17,int(118*scale),5,body),(x,y+28,int(96*scale),5,body)]
    for (bx,by,bw,bh,c) in rows:
        if shadow: d.rounded_rectangle((bx+1,by+1,bx+bw+1,by+bh+1),bh//2,fill=(0,0,0,200))
        d.rounded_rectangle((bx,by,bx+bw,by+bh),bh//2,fill=c)
def rgb(c): return tuple(int(v*255) for v in c)+(255,)
def slice_theme(tex,hdr,body,scale=0.62,shadow=False,decor=None):
    im=bgimg(); T=Image.open(A+tex).convert("RGBA")
    T=T.resize((int(T.width*scale),int(T.height*scale)),Image.LANCZOS)
    m=int(44*scale); fw,fh=W-16,H-14
    fr=nine(T,fw,fh,(m,m,m,m))
    if decor:
        D=Image.open(A+decor).convert("RGBA"); s=int(fh*0.95); D=D.resize((s,s),Image.LANCZOS)
        D.putalpha(D.split()[3].point(lambda v:int(v*0.18))); fr.alpha_composite(D,((fw-s)//2,(fh-s)//2))
    im.alpha_composite(fr,(8,7)); bars(im,8+int(30*scale)+10,7+int(26*scale)+12,rgb(hdr),rgb(body),shadow); return im
def band_theme(tex,xc,bands,cap,inset,hdr,body,shadow=False):
    im=bgimg(); T=Image.open(A+tex).convert("RGBA"); TW,TH=T.size
    x1,x2=int(xc[0]*TW),int(xc[1]*TW); y0,y1,y2,y3=[int(v*TH) for v in bands]
    fw=W-20; capS=int(cap*0.62); mid=H-14-2*capS
    top=T.crop((x1,y0,x2,y1)).resize((fw,capS)); midI=T.crop((x1,y1,x2,y2)).resize((fw,mid)); bot=T.crop((x1,y2,x2,y3)).resize((fw,capS))
    im.alpha_composite(top,(10,7)); im.alpha_composite(midI,(10,7+capS)); im.alpha_composite(bot,(10,7+capS+mid))
    bars(im,10+int(inset*0.62)+12,7+capS+4,rgb(hdr),rgb(body),shadow); return im
def dui_theme(tex,hdr,body,shadow=False):
    im=bgimg(); T=Image.open(A+tex).convert("RGBA"); TW,TH=T.size
    T=T.crop((0,0,TW,int(TH*0.53))); fw,fh=int((W-8)/(1-0.259)),int((H-6)/(1-0.169))
    T=T.resize((fw,fh),Image.LANCZOS); im.alpha_composite(T,(4-int(0.129*fw),3-int(0.116*fh)))
    bars(im,36,36,rgb(hdr),rgb(body),shadow); return im
def bubble_theme(bub,pill,ink):
    im=bgimg(); B=Image.open(A+bub).convert("RGBA")
    fr=nine(B,150,48,(24,24,24,24)) if B.width>=64 else None
    if fr: im.alpha_composite(fr,(10,8))
    t=Image.open(A+bub.replace(".png","Tail.png")).convert("RGBA").resize((18,18)) if "Fantasy" in bub else None
    if t: im.alpha_composite(t,(70,52))
    d=ImageDraw.Draw(im); d.rounded_rectangle((24,22,24+96,27),2,fill=ink); d.rounded_rectangle((24,33,24+70,37),2,fill=ink)
    P=Image.open(A+pill+"TailDown.png").convert("RGBA")
    p1=nine(P,12+120,30+9,(26,14,14,23)); im.alpha_composite(p1,(118,70))
    d.rounded_rectangle((150,82,150+74,87),2,fill=ink)
    return im
def game_bubble():
    im=bgimg(); d=ImageDraw.Draw(im)
    d.rounded_rectangle((12,10,160,56),10,fill=(250,250,245,235),outline=(40,40,40,255),width=2)
    d.polygon([(70,55),(84,55),(74,66)],fill=(250,250,245,235)); d.line([(70,56),(74,66),(84,56)],fill=(40,40,40,255),width=2)
    d.rounded_rectangle((26,24,26+96,29),2,fill=(30,30,30,255)); d.rounded_rectangle((26,35,26+70,39),2,fill=(30,30,30,255))
    P=Image.open(A+"PillDarkTailDown.png").convert("RGBA"); im.alpha_composite(nine(P,132,39,(26,14,14,23)),(118,70))
    d=ImageDraw.Draw(im); d.rounded_rectangle((150,82,224,87),2,fill=(255,224,40,255)); return im
def transparent():
    im=bgimg(); bars(im,30,40,(255,216,38,255),(242,235,218,255),shadow=True); return im
def dark():
    im=bgimg(); d=ImageDraw.Draw(im)
    d.rounded_rectangle((14,12,W-14,H-12),6,fill=(13,13,18,210),outline=(102,102,115,230),width=2)
    bars(im,32,36,(255,216,38,255),(242,235,218,255),shadow=True); return im
out={
 "velin":slice_theme("ThemeVelin.png",(0.43,0.20,0.03),(0.17,0.10,0.04)),
 "arcane":slice_theme("ThemeArcane.png",(0.16,0.24,0.47),(0.16,0.13,0.12),decor="ThemeArcaneSigil.png"),
 "sylvan":slice_theme("ThemeSylvan.png",(0.24,0.31,0.08),(0.16,0.12,0.05)),
 "starry":slice_theme("ThemeStarry.png",(1,0.84,0.43),(0.92,0.89,0.84),shadow=True),
 "parchment":band_theme("Parchment.png",(0,1),(0,96/512,416/512,1),34,30,(0.24,0.12,0.03),(0.13,0.08,0.03)),
 "parchment_dark":band_theme("themes.tga",(0.52,0.96),(0.05,0.21,0.79,0.95),26,36,(1,0.85,0.15),(0.95,0.92,0.85),True),
 "dui_brown":dui_theme("ParchmentDUIBrown.png",(0.16,0.08,0.02),(0.10,0.05,0.02)),
 "dui_dark":dui_theme("ParchmentDUIDark.png",(1,0.85,0.15),(0.95,0.92,0.85),True),
 "bubble":game_bubble(),
 "bubble_fantasy":bubble_theme("BubbleFantasy.png","PillFantasy",(45,25,10,255)),
 "transparent":transparent(),
 "dark":dark(),
}
names={"velin":"Velin","arcane":"Arcane","sylvan":"Sylvan","starry":"Starry","parchment":"Parchment","parchment_dark":"ParchmentDark","dui_brown":"DUIBrown","dui_dark":"DUIDark","bubble":"Bubble","bubble_fantasy":"BubbleFantasy","transparent":"Transparent","dark":"Dark"}
sheet=Image.new("RGBA",(4*262,3*134),(20,20,20,255))
for i,(k,im) in enumerate(out.items()):
    im.save(A+"Thumbs/"+names[k]+".png") if False else None
    import os; os.makedirs(A+"Thumbs",exist_ok=True); im.convert("RGBA").save(A+"Thumbs/"+names[k]+".png")
    sheet.alpha_composite(im,((i%4)*262,(i//4)*134))
sheet.save("/tmp/thumbs.png"); print("ok")

# --- nouveaux themes
def whisper_thumb():
    im=bgimg(); B=Image.open(A+"BubbleWhisper.png").convert("RGBA")
    im.alpha_composite(nine(B,150,48,(16,16,16,16)),(10,8))
    t=Image.open(A+"BubbleWhisperTail.png").convert("RGBA").resize((22,22),Image.LANCZOS); im.alpha_composite(t,(64,48))
    d=ImageDraw.Draw(im); d.rounded_rectangle((24,22,120,27),2,fill=(255,156,255,255)); d.rounded_rectangle((24,33,94,37),2,fill=(255,156,255,255))
    P=Image.open(A+"PillWhisperSelTailDown.png").convert("RGBA"); im.alpha_composite(nine(P,132,39,(26,14,14,23)),(118,70))
    d.rounded_rectangle((150,82,224,87),2,fill=(255,158,255,255)); return im
def glass_thumb():
    im=bgimg().filter(ImageFilter.GaussianBlur(2)); T=Image.open(A+"ThemeGlass.png").convert("RGBA")
    im.alpha_composite(nine(T,W-28,H-24,(14,14,14,14)),(14,12))
    bars(im,32,36,(255,214,128,255),(240,235,225,255),shadow=True); return im
whisper_thumb().save(A+"Thumbs/Whisper.png"); glass_thumb().save(A+"Thumbs/Glass.png")
s2=Image.new("RGBA",(2*262,134),(20,20,20,255)); s2.alpha_composite(Image.open(A+"Thumbs/Whisper.png")); s2.alpha_composite(Image.open(A+"Thumbs/Glass.png"),(262,0)); s2.save("/tmp/t2.png")
