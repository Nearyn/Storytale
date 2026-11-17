import numpy as np
from PIL import Image, ImageDraw, ImageFont
A="./"
BG=Image.open("clean.png").convert("RGBA").crop((380,150,1200,830))
SANS="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"; SANSB="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
BASK=A+"Fonts/LibreBaskerville-Regular.ttf"
NAME="Stormwind Harbor Guard"; SAY="Welcome to Stormwind, traveler. What do you need directions to?"
CHO=["Dialogue","Profession Trainer","Class Trainer","Battlemaster","Officers' Lounge","Goodbye"]; SEL=1
def c(t,a=255): return tuple(int(v*255) for v in t[:3])+(a,)
def nine(T,w,h,m):
    l,t,r,b=m; TW,TH=T.size; out=Image.new("RGBA",(w,h))
    xs=[(0,l,0,l),(l,TW-r,l,w-r),(TW-r,TW,w-r,w)]; ys=[(0,t,0,t),(t,TH-b,t,h-b),(TH-b,TH,h-b,h)]
    for a,b2,cx,d in xs:
        for e,f,g,h2 in ys:
            if d>cx and h2>g and b2>a and f>e: out.paste(T.crop((a,e,b2,f)).resize((d-cx,h2-g),Image.LANCZOS),(cx,g))
    return out
def tex(n): return Image.open(A+n).convert("RGBA")
def wrap(d,s,font,w):
    out=[];cur=""
    for word in s.split():
        t=(cur+" "+word).strip()
        if d.textlength(t,font=font)<=w: cur=t
        else: out.append(cur);cur=word
    out.append(cur);return out
def txt(d,xy,s,font,fill,shadow):
    if shadow: d.text((xy[0]+1,xy[1]+1),s,font=font,fill=(0,0,0,230))
    d.text(xy,s,font=font,fill=fill)
STY={
 "dark":dict(bg=(0.05,0.05,0.07,0.82),border=(0.4,0.4,0.45,0.9),hdr=(1,0.85,0.15),body=(0.95,0.92,0.85),shadow=1),
 "parchment":dict(tex="Parchment.png",bands=(0,96/512,416/512,1),cap=34,inset=(30,0,30,0),div=(0.36,0.22,0.09,0.45),hdr=(0.24,0.12,0.03),body=(0.13,0.08,0.03),shadow=0),
 "velin":dict(tex="ThemeVelin.png",slice=(44,)*4,pad=(30,26,30,26),div=(0.62,0.45,0.15,0.6),hdr=(0.43,0.20,0.03),body=(0.17,0.10,0.04),shadow=0),
 "arcane":dict(tex="ThemeArcane.png",slice=(44,)*4,pad=(30,26,30,26),decor=("ThemeArcaneSigil.png",0.16,0.95),div=(0.35,0.50,0.85,0.55),hdr=(0.16,0.24,0.47),body=(0.16,0.13,0.12),shadow=0),
 "sylvan":dict(tex="ThemeSylvan.png",slice=(44,)*4,pad=(30,26,30,26),div=(0.35,0.45,0.15,0.55),hdr=(0.24,0.31,0.08),body=(0.16,0.12,0.05),shadow=0),
 "glass":dict(tex="ThemeGlass.png",slice=(14,)*4,pad=(14,11,14,11),div=(0.90,0.75,0.45,0.45),hdr=(1,0.84,0.50),body=(0.94,0.92,0.88),shadow=1),
 "halo":dict(tex="ThemeHalo.png",slice=(48,)*4,pad=(40,30,40,30),div=(1,0.85,0.4,0),hdr=(1,0.84,0.27),body=(0.95,0.93,0.89),shadow=1),
 "inkgold":dict(tex="ThemeInk.png",slice=(24,20,24,20),pad=(22,14,26,14),div=(0.83,0.67,0.31,0.35),hdr=(1,0.84,0.47),body=(0.96,0.93,0.84),shadow=1,font=BASK),
 "starry":dict(tex="ThemeStarry.png",slice=(44,)*4,pad=(30,26,30,26),div=(0.85,0.68,0.30,0.55),hdr=(1,0.84,0.43),body=(0.92,0.89,0.84),shadow=1),
 "parchment_dark":dict(tex="themes.tga",xcoord=(0.52,0.96),bands=(0.05,0.21,0.79,0.95),cap=26,inset=(36,-8,20,-8),tint=0.96,div=(0.70,0.72,0.78,0.35),hdr=(1,0.85,0.15),body=(0.95,0.92,0.85),shadow=1),
 "dui_brown":dict(tex="ParchmentDUIBrown.png",coord=(0,1,0,0.53),clear=(0.129,0.116,0.13,0.053),margin=(24,20),div=(0.35,0.22,0.10,0.45),hdr=(0.16,0.08,0.02),body=(0.10,0.05,0.02),shadow=0),
 "dui_dark":dict(tex="ParchmentDUIDark.png",coord=(0,1,0,0.53),clear=(0.129,0.116,0.13,0.053),margin=(24,20),div=(0.70,0.72,0.78,0.35),hdr=(1,0.85,0.15),body=(0.95,0.92,0.85),shadow=1),
 "transparent":dict(none=1,hdr=(1,0.85,0.15),body=(0.95,0.92,0.85),shadow=1),
}
LIGHT={"parchment","dui_brown","velin","arcane","sylvan"}
def paint(im,cfg,x,y,w,h):
    if cfg.get("none"): return
    if "bg" in cfg:
        d=ImageDraw.Draw(im); d.rounded_rectangle((x-11,y-11,x+w+11,y+h+11),5,fill=c(cfg["bg"],int(cfg["bg"][3]*255)))
        d.rounded_rectangle((x-13,y-13,x+w+13,y+h+13),6,outline=c(cfg["border"],230),width=3); return
    T=tex(cfg["tex"])
    if "slice" in cfg:
        pl,pt,pr,pb=cfg["pad"]; fr=nine(T,w+pl+pr,h+pt+pb,cfg["slice"]); im.alpha_composite(fr,(x-pl,y-pt))
        if "decor" in cfg:
            n,al,sz=cfg["decor"]; s=int(min(w+pl+pr,h+pt+pb)*sz); D=tex(n).resize((s,s),Image.LANCZOS)
            D.putalpha(D.split()[3].point(lambda v:int(v*al))); im.alpha_composite(D,(x+w//2-s//2,y+h//2-s//2))
        return
    if "bands" in cfg:
        TW,TH=T.size; x1,x2=[int(v*TW) for v in cfg.get("xcoord",(0,1))]; y0,y1,y2,y3=[int(v*TH) for v in cfg["bands"]]
        il,it,ir,ib=cfg["inset"]; bx,by,bw,bh=x-il,y-it,w+il+ir,h+it+ib; cap=cfg["cap"]
        parts=[(y0,y1,by-cap,cap),(y1,y2,by,bh),(y2,y3,by+bh,cap)]
        for a,b,py,ph in parts:
            p=T.crop((x1,a,x2,b)).resize((bw,ph),Image.LANCZOS)
            if cfg.get("tint"): p.putalpha(p.split()[3].point(lambda v:int(v*cfg["tint"])))
            im.alpha_composite(p,(bx,py))
        return
    cl,ct,cr,cb=cfg["clear"]; mx,my=cfg["margin"]; W=(w+2*mx)/(1-cl-cr); H=(h+2*my)/(1-ct-cb)
    TW,TH=T.size; u0,u1,v0,v1=cfg["coord"]; p=T.crop((int(u0*TW),int(v0*TH),int(u1*TW),int(v1*TH))).resize((int(W),int(H)),Image.LANCZOS)
    im.alpha_composite(p,(int(x-mx-cl*W),int(y-my-ct*H)))
def block(cfg,wheel=True):
    im=BG.copy(); d=ImageDraw.Draw(im)
    fp=cfg.get("font",SANS); fb=ImageFont.truetype(fp,17); fh=ImageFont.truetype(fp if "font" in cfg else SANSB,19)
    lines=wrap(d,SAY,fb,330); x,y=40,40; w=int(max(d.textlength(l,font=fb) for l in lines+[NAME])+4)
    h=26+len(lines)*23
    lay=Image.new("RGBA",im.size); paint(lay,cfg,x,y,w,h); im.alpha_composite(lay); d=ImageDraw.Draw(im)
    sh=cfg["shadow"]==1
    txt(d,(x,y),NAME,fh,c(cfg["hdr"]),sh)
    if cfg.get("div") and cfg["div"][3]>0 and not cfg.get("none"): d.line([(x,y+24),(x+w,y+24)],fill=c(cfg["div"],int(cfg["div"][3]*255)))
    for i,l in enumerate(lines): txt(d,(x,y+30+i*23),l,fb,c(cfg["body"]),sh)
    # roue (option "habiller la roue" cochée)
    ink=cfg_id in LIGHT
    wx,wy,ww=520,300,230; rh=40; wh=rh*len(CHO)
    lay=Image.new("RGBA",im.size); paint(lay,cfg,wx,wy,ww,wh); im.alpha_composite(lay); d=ImageDraw.Draw(im)
    fw=ImageFont.truetype(fp,17)
    for i,ch in enumerate(CHO):
        if ink: col=(0.55,0.20,0.0) if i==SEL else ((0.36,0.27,0.19) if ch=="Goodbye" else (0.16,0.09,0.03))
        else: col=(1,0.88,0.15) if i==SEL else ((0.67,0.67,0.67) if ch=="Goodbye" else (0.95,0.92,0.85))
        txt(d,(wx+8,wy+8+i*rh),ch,fw,c(col),not ink)
    return im
PILL={"bubble":("PillDark","PillDarkSel",(0.95,0.92,0.85),(1,0.88,0.15),1),
      "bubble_fantasy":("PillFantasy","PillFantasySel",(0.16,0.09,0.03),(0.55,0.20,0.0),0),
      "whisper":("PillWhisper","PillWhisperSel",(0.96,0.88,0.98),(1,0.62,1),1)}
def bubble(kind):
    im=BG.copy(); d=ImageDraw.Draw(im); fb=ImageFont.truetype(SANS,18)
    lines=wrap(d,SAY,fb,300); w=int(max(d.textlength(l,font=fb) for l in lines))+4; h=len(lines)*24
    bx,by=280-w//2,40
    lay=Image.new("RGBA",im.size); L=ImageDraw.Draw(lay)
    if kind=="bubble":
        p=14; L.rounded_rectangle((bx-p,by-p,bx+w+p,by+h+p),9,fill=(0,0,0,215),outline=(225,225,225,255),width=2)
        L.polygon([(300,by+h+p-1),(318,by+h+p-1),(306,by+h+p+14)],fill=(0,0,0,215)); L.line([(300,by+h+p),(306,by+h+p+14),(318,by+h+p)],fill=(225,225,225,255),width=2)
        col=(255,255,255,255)
    else:
        art,sl,p,col=("BubbleFantasy",24,20,(46,26,10,255)) if kind=="bubble_fantasy" else ("BubbleWhisper",16,14,(255,168,255,255))
        lay.alpha_composite(nine(tex(art+".png"),w+2*p,h+2*p,(sl,)*4),(bx-p,by-p))
        t=tex(art+"Tail.png"); lay.alpha_composite(t,(300,by+h+p-6))
    im.alpha_composite(lay); d=ImageDraw.Draw(im)
    for i,l in enumerate(lines): d.text((bx,by+i*24),l,font=fb,fill=col)
    n,s,cn,cs,sh=PILL[kind]; wx,wy=520,300; fw=ImageFont.truetype(SANS,17)
    for i,ch in enumerate(CHO):
        T=tex((s if i==SEL else n)+".png"); tw=int(d.textlength(ch,font=fw))+40
        im.alpha_composite(nine(T,tw,36,(12,12,12,12)),(wx,wy+i*44)); d=ImageDraw.Draw(im)
        txt(d,(wx+20,wy+8+i*44),ch,fw,c(cs if i==SEL else cn),sh==1)
    return im
def cinema():
    im=BG.copy(); W,H=im.size; d=ImageDraw.Draw(im)
    d.rectangle((0,0,W,int(H*0.09)),fill=(0,0,0,255)); bh=int(H*0.15); d.rectangle((0,H-bh,W,H),fill=(0,0,0,255))
    f=ImageFont.truetype(BASK,19); f2=ImageFont.truetype(BASK,15)
    lines=wrap(d,SAY,f,600); y=H-bh+(bh-(20+len(lines)*26))//2
    txt(d,((W-d.textlength(NAME,font=f2))/2,y),NAME,f2,c((0.85,0.66,0.32)),True)
    for i,l in enumerate(lines): txt(d,((W-d.textlength(l,font=f))/2,y+22+i*26),l,f,c((0.95,0.91,0.82)),True)
    fw=ImageFont.truetype(BASK,17)
    for i,ch in enumerate(CHO):
        col=(1,0.88,0.15) if i==SEL else ((0.67,0.67,0.67) if ch=="Goodbye" else (0.95,0.92,0.85))
        txt(d,(528,268+i*40),ch,fw,c(col),True)
    return im
import sys
ids=["bubble","bubble_fantasy","whisper","transparent","dark","glass","halo","inkgold","cinema","velin","arcane","sylvan","starry","parchment","parchment_dark","dui_brown","dui_dark"]
for cfg_id in ids:
    if cfg_id in PILL: im=bubble(cfg_id)
    elif cfg_id=="cinema": im=cinema()
    else: im=block(STY[cfg_id])
    im=im.convert("RGB").resize((600,int(600*im.height/im.width)),Image.LANCZOS)
    im.save("%s.jpg"%cfg_id,quality=88)
# planche de controle
ims=[Image.open("%s.jpg"%i) for i in ids]; w,h=ims[0].size
sheet=Image.new("RGB",(w*5,h*4))
for i,m in enumerate(ims): sheet.paste(m,((i%5)*w,(i//5)*h))
sheet.resize((sheet.width//2,sheet.height//2)).save("/tmp/sheet.jpg")
