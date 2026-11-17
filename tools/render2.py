exec(open("base2.py").read())
NPCX=280   # tete du garde
WX,WY=372,150
INKP={"parchment","dui_brown","velin","arcane","sylvan"}
ART={"dark":"Veil","glass":"Glass","halo":"Halo","inkgold":"Ink","velin":"Velin","arcane":"Arcane","sylvan":"Sylvan","starry":"Starry","parchment":"Parch","parchment_dark":"ParchDark","dui_brown":"DUIBrown","dui_dark":"DUIDark"}
SAY="Welcome to Stormwind, traveler. What do you need directions to?"
def palette(ink,whisper=False):
    if whisper: return (0.96,0.88,0.98),(1,0.62,1),(0.75,0.66,0.78)
    if ink: return (0.16,0.09,0.03),(0.55,0.20,0.0),(0.36,0.27,0.19)
    return (0.95,0.92,0.85),(1,0.88,0.15),(0.67,0.67,0.67)
def wheel_plain(im,ink,font):
    d=ImageDraw.Draw(im); n,sc,gb=palette(ink)
    for i,ch in enumerate(CHO):
        col=sc if i==SEL else (gb if ch=="Goodbye" else n)
        txt(d,(WX+10,WY+8+i*38),ch,font,c(col),not ink)
def wheel_pills(im,pn,ps,ink,whisper=False,font=None):
    d=ImageDraw.Draw(im); n,sc,gb=palette(ink,whisper); font=font or ImageFont.truetype(SANS,18)
    pw=int(max(d.textlength(ch,font=font) for ch in CHO))+44
    for i,ch in enumerate(CHO):
        y=WY+i*44
        if i==SEL:
            T=tex(ps+"Tail.png"); im.alpha_composite(nine(T,pw+12,36,(26,34,14,14)),(WX-12,y))
        else:
            im.alpha_composite(nine(tex(pn+".png"),pw,36,(12,12,12,12)),(WX,y))
        d=ImageDraw.Draw(im); col=sc if i==SEL else (gb if ch=="Goodbye" else n)
        txt(d,(WX+18,y+7),ch,font,c(col),not ink)
def speech(im,art,slice_,pad,col,font,game=False,shadow=False):
    d=ImageDraw.Draw(im); lines=wrap(d,SAY,font,300)
    w=int(max(d.textlength(l,font=font) for l in lines))+4; lh=font.size+6; h=len(lines)*lh
    bx=NPCX-w//2+40; by=105-h-pad
    lay=Image.new("RGBA",im.size)
    if game:
        L=ImageDraw.Draw(lay); p=pad
        L.rounded_rectangle((bx-p,by-p,bx+w+p,by+h+p),9,fill=(0,0,0,215),outline=(225,225,225,255),width=2)
        tx=NPCX; L.polygon([(tx-8,by+h+p-1),(tx+8,by+h+p-1),(tx-2,by+h+p+13)],fill=(0,0,0,215))
        L.line([(tx-8,by+h+p),(tx-2,by+h+p+13),(tx+8,by+h+p)],fill=(225,225,225,255),width=2)
    else:
        lay.alpha_composite(nine(tex(art+".png"),w+2*pad,h+2*pad,(slice_,)*4),(bx-pad,by-pad))
        lay.alpha_composite(tex(art+"Tail.png"),(NPCX-16,by+h+pad-8))
    im.alpha_composite(lay); d=ImageDraw.Draw(im)
    for i,l in enumerate(lines): txt(d,(bx,by+i*lh),l,font,col,shadow)
def bubble_view(tid):
    im=BG.copy()
    if tid=="bubble":
        speech(im,None,0,14,(255,255,255,255),ImageFont.truetype(SANS,18),game=True); wheel_pills(im,"PillDark","PillDarkSel",False)
    elif tid=="bubble_fantasy":
        f=ImageFont.truetype(SANS,18)
        speech(im,"BubbleFantasy",24,20,(46,26,10,255),f); wheel_pills(im,"PillFantasy","PillFantasySel",True,font=f)
    elif tid=="whisper":
        speech(im,"BubbleWhisper",16,14,(255,168,255,255),ImageFont.truetype(SANS,18)); wheel_pills(im,"PillWhisper","PillWhisperSel",False,True)
    else:
        a=ART[tid]; cfg=STY[tid]; f=ImageFont.truetype(cfg.get("font",SANS),18)
        speech(im,"Bubble"+a,16,14,c(cfg["body"]),f,shadow=cfg["shadow"]==1)
        wheel_pills(im,"Pill"+a,"Pill"+a+"Sel",tid in INKP,font=f)
    return im
def frame_view(tid):
    im=BG.copy(); cfg=STY[tid]; d=ImageDraw.Draw(im)
    fp=cfg.get("font",SANS); fb=ImageFont.truetype(fp,17); fh=ImageFont.truetype(fp if "font" in cfg else SANSB,19)
    lines=wrap(d,SAY,fb,330); w=int(max(d.textlength(l,font=fb) for l in lines+[NAME])+4); h=26+len(lines)*23
    x,y=40,30
    lay=Image.new("RGBA",im.size); paint(lay,cfg,x,y,w,h); im.alpha_composite(lay); d=ImageDraw.Draw(im)
    sh=cfg["shadow"]==1
    txt(d,(x,y),NAME,fh,c(cfg["hdr"]),sh)
    if cfg.get("div") and cfg["div"][3]>0: d.line([(x,y+24),(x+w,y+24)],fill=c(cfg["div"],int(cfg["div"][3]*255)))
    for i,l in enumerate(lines): txt(d,(x,y+30+i*23),l,fb,c(cfg["body"]),sh)
    lay=Image.new("RGBA",im.size); paint(lay,cfg,WX,WY,240,38*len(CHO)); im.alpha_composite(lay)
    wheel_plain(im,tid in INKP,ImageFont.truetype(fp,18))
    return im
def cinema_view():
    im=BG.copy(); W,H=im.size; d=ImageDraw.Draw(im)
    d.rectangle((0,0,W,int(H*0.09)),fill=(0,0,0,255)); bh=int(H*0.16); d.rectangle((0,H-bh,W,H),fill=(0,0,0,255))
    f=ImageFont.truetype(BASK,19); f2=ImageFont.truetype(BASK,15); lines=wrap(d,SAY,f,700); y=H-bh+(bh-(22+len(lines)*26))//2
    txt(d,((W-d.textlength(NAME,font=f2))/2,y),NAME,f2,c((0.85,0.66,0.32)),True)
    for i,l in enumerate(lines): txt(d,((W-d.textlength(l,font=f))/2,y+22+i*26),l,f,c((0.95,0.91,0.82)),True)
    wheel_plain(im,False,ImageFont.truetype(BASK,18)); return im
out={}
for t in ["bubble","bubble_fantasy","whisper"]: out[t]=bubble_view(t)
for t in ART: out[t+"_bubble"]=bubble_view(t); out[t]=frame_view(t)
out["transparent"]=frame_view("transparent"); out["cinema"]=cinema_view()
import os; os.makedirs("v2",exist_ok=True)
for k,im in out.items(): im.convert("RGB").save("v2/%s.jpg"%k,quality=92)
ks=list(out); w,h=out[ks[0]].size
sheet=Image.new("RGB",(w*6,h*((len(ks)+5)//6)))
for i,k in enumerate(ks): sheet.paste(out[k].convert("RGB"),((i%6)*w,(i//6)*h))
sheet.resize((sheet.width//3,sheet.height//3)).save("/tmp/sheet2.jpg"); print(len(ks))
