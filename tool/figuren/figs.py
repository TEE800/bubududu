"""Zeichnet Bubu (Fritzi) und Dudu (Kevin) als SVG, je Stimmung. Siehe export.py."""
import random, math
R=random.Random(7)
O='#3B2418'; ST=f'stroke="{O}" stroke-width="4.5" stroke-linejoin="round" stroke-linecap="round"'
SK='#F5CDB2'; SKS='#E6AE90'; SKL='#FDE4D3'
BE='#3E2B1F'; BED='#291A11'; BEL='#6A4E3B'; GREY='#C4BCB3'
KE='#5E8FB3'; FE='#6B4226'
HA='#5E3B24'; HAD='#43291A'; HAL='#8A5F40'
GR='#22915A'; GRD='#187044'; BK='#2A2C33'; BKD='#1C1D22'; MINT='#BFE6CB'; SIL='#D5D9DE'; PANTS='#46536A'

def eye(x,y,iris,rx=15,ry=18):
    s=f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="#1C1310"/>'
    s+=f'<ellipse cx="{x}" cy="{y+4}" rx="{rx-4}" ry="{ry-6}" fill="{iris}"/>'
    s+=f'<ellipse cx="{x}" cy="{y+5}" rx="{rx-8}" ry="{ry-10}" fill="#1C1310"/>'
    s+=f'<circle cx="{x+5}" cy="{y-6}" r="5.5" fill="#fff"/><circle cx="{x-5}" cy="{y+8}" r="2.5" fill="#fff" opacity=".9"/>'
    return s

def heart(x,y,s,c="#E5484D"):
    return f'<path transform="translate({x} {y}) scale({s})" d="M0,10 C-14,-2 -12,-16 0,-9 C12,-16 14,-2 0,10Z" fill="{c}" stroke="#B83238" stroke-width="1.5"/>'

def legs(cx,gap):
    s=""
    for d in (-gap,gap):
        s+=f'<rect x="{cx+d-15}" y="500" width="30" height="46" rx="12" fill="{PANTS}" {ST}/>'
        s+=f'<path d="M{cx+d-22},556 C{cx+d-22},538 {cx+d+22},538 {cx+d+24},556Z" fill="#F4F4F4" {ST}/>'
    return s

def arm(path,col):
    return (f'<path d="{path}" stroke="{O}" stroke-width="34" fill="none" stroke-linecap="round"/>'
            f'<path d="{path}" stroke="{col}" stroke-width="25" fill="none" stroke-linecap="round"/>')

def kevin(cx=255,mood='happy'):
    s=[legs(cx,32)]
    body=f"M{cx-95},470 C{cx-100},390 {cx-60},356 {cx},356 C{cx+60},356 {cx+100},390 {cx+95},470 C{cx+92},515 {cx+60},520 {cx},520 C{cx-60},520 {cx-92},515 {cx-95},470Z"
    s.append(f'<path d="{body}" fill="{GR}" {ST}/>')
    s.append(f'<path d="M{cx+60},372 C{cx+95},400 {cx+100},470 {cx+80},508 C{cx+60},518 {cx+50},516 {cx+40},518 C{cx+70},470 {cx+70},410 {cx+60},372Z" fill="{GRD}" opacity=".7"/>')
    s.append(f'<path d="M{cx-40},478 h80 v26 q-40,10 -80,0Z" fill="{GRD}" {ST}/>')
    for d in (-14,14):
        s.append(f'<path d="M{cx+d},420 v40" stroke="#F1F8F2" stroke-width="5" stroke-linecap="round"/>')
    s.append(arm(f"M{cx-80},400 Q{cx-118},440 {cx-108},480",GR)+f'<circle cx="{cx-108}" cy="488" r="16" fill="{SK}" {ST}/>')
    s.append(arm(f"M{cx+80},402 Q{cx+112},430 {cx+128},452",GR))
    # ears
    for x,sg in ((140,-1),(370,1)):
        x=cx+(x-255)
        s.append(f'<ellipse cx="{x}" cy="232" rx="20" ry="26" fill="{SK}" {ST}/><path d="M{x+sg*-2},220 q{sg*10},12 0,24" stroke="{SKS}" stroke-width="4" fill="none" stroke-linecap="round"/>')
    head=f"M{cx-118},220 C{cx-118},128 {cx-66},86 {cx},86 C{cx+66},86 {cx+118},128 {cx+118},220 C{cx+118},296 {cx+70},336 {cx},338 C{cx-70},336 {cx-118},296 {cx-118},220Z"
    s.append(f'<clipPath id="kh"><path d="{head}"/></clipPath><path d="{head}" fill="{SK}"/>')
    s.append(f'<g clip-path="url(#kh)"><path d="M{cx+70},80 C{cx+140},150 {cx+130},290 {cx+60},350 L{cx+140},350 L{cx+140},80Z" fill="{SKS}" opacity=".45"/></g>')
    s.append(f'<ellipse cx="{cx-46}" cy="128" rx="38" ry="18" fill="#fff" opacity=".55" transform="rotate(-25 {cx-46} 128)"/><ellipse cx="{cx-58}" cy="122" rx="12" ry="6" fill="#fff" transform="rotate(-25 {cx-58} 122)"/>')
    s.append(f'<path d="{head}" fill="none" {ST}/>')
    if mood=='sad': s.append(f'<path d="M{cx-70},176 C{cx-56},178 {cx-30},170 {cx-16},160" stroke="{BE}" stroke-width="13" fill="none" stroke-linecap="round"/><path d="M{cx+70},176 C{cx+56},178 {cx+30},170 {cx+16},160" stroke="{BE}" stroke-width="13" fill="none" stroke-linecap="round"/>')
    else: s.append(f'<path d="M{cx-72},186 C{cx-60},168 {cx-30},166 {cx-14},176" stroke="{BE}" stroke-width="13" fill="none" stroke-linecap="round"/><path d="M{cx+72},186 C{cx+60},168 {cx+30},166 {cx+14},176" stroke="{BE}" stroke-width="13" fill="none" stroke-linecap="round"/>')
    s.append(eyes(cx,222,KE,15,18,44,mood))
    s.append(f'<ellipse cx="{cx-76}" cy="258" rx="20" ry="11" fill="#F59A94" opacity=".55"/><ellipse cx="{cx+76}" cy="258" rx="20" ry="11" fill="#F59A94" opacity=".55"/>')
    s.append(f'<path d="M{cx-12},252 C{cx-16},266 {cx-6},270 {cx},268 C{cx+6},270 {cx+16},266 {cx+12},252" fill="{SKS}" stroke="{O}" stroke-width="3.5" stroke-linecap="round"/>')
    beard=(f"M{cx-116},214 C{cx-124},330 {cx-80},420 {cx},428 C{cx+80},420 {cx+124},330 {cx+116},214 "
           f"C{cx+108},250 {cx+94},274 {cx+66},280 C{cx+46},284 {cx+28},274 {cx},276 C{cx-28},274 {cx-46},284 {cx-66},280 C{cx-94},274 {cx-108},250 {cx-116},214Z")
    s.append('<filter id="fz" x="-10%" y="-10%" width="120%" height="120%"><feTurbulence type="fractalNoise" baseFrequency=".06" numOctaves="1" seed="5"/><feDisplacementMap in="SourceGraphic" scale="10"/></filter>')
    s.append(f'<clipPath id="kb"><path d="{beard}"/></clipPath>')
    s.append(f'<g filter="url(#fz)"><path d="{beard}" fill="{BE}" stroke="{O}" stroke-width="4.5"/></g>')
    s.append(f'<g clip-path="url(#kb)"><path d="M{cx+30},280 C{cx+120},300 {cx+110},420 {cx+40},440 L{cx+140},440 L{cx+140},280Z" fill="{BED}" opacity=".55"/>'
             f'<path d="M{cx-80},320 C{cx-70},380 {cx-40},400 {cx-20},404 C{cx-50},380 {cx-62},350 {cx-60},320Z" fill="{BEL}" opacity=".6"/>')
    # cute tufts
    for i in range(26):
        x=cx+R.uniform(-90,90); y=R.uniform(300,410)
        c=R.choice([BEL,BEL,BED,GREY])
        s.append(f'<path d="M{x:.0f},{y:.0f} q5,7 0,14 M{x+7:.0f},{y+2:.0f} q5,7 0,13" stroke="{c}" stroke-width="2.6" fill="none" stroke-linecap="round"/>')
    s.append('</g>')
    # mustache + open smile
    s.append(f'<path d="M{cx-44},290 C{cx-30},272 {cx-10},272 {cx},282 C{cx+10},272 {cx+30},272 {cx+44},290 C{cx+24},288 {cx+12},292 {cx},292 C{cx-12},292 {cx-24},288 {cx-44},290Z" fill="{BED}" stroke="{O}" stroke-width="3"/>')
    s.append(mouth(cx,296,mood,24))
    return "".join(s)

def fritzi(cx=505,mood='happy'):
    s=[legs(cx,26)]
    body=f"M{cx-80},470 C{cx-84},390 {cx-50},360 {cx},360 C{cx+50},360 {cx+84},390 {cx+80},470 C{cx+78},515 {cx+50},520 {cx},520 C{cx-50},520 {cx-78},515 {cx-80},470Z"
    s.append(f'<path d="{body}" fill="{BK}" {ST}/>')
    s.append(f'<path d="M{cx+50},374 C{cx+82},400 {cx+86},470 {cx+70},508 C{cx+56},516 {cx+46},516 {cx+36},518 C{cx+62},470 {cx+60},410 {cx+50},374Z" fill="{BKD}"/>')
    s.append(f'<path d="M{cx-26},362 C{cx-14},384 {cx+14},384 {cx+26},362Z" fill="{MINT}" {ST}/>')
    s.append(f'<path d="M{cx},382 V518" stroke="{SIL}" stroke-width="3.5"/><path d="M{cx-50},368 C{cx-46},350 {cx-30},344 {cx-22},360 M{cx+50},368 C{cx+46},350 {cx+30},344 {cx+22},360" stroke="{O}" stroke-width="4" fill="#3A3D46"/>')
    s.append(f'<path d="M{cx-40},470 h26 v22 h-26Z M{cx+14},470 h26 v22 h-26Z" fill="#33363E" stroke="{O}" stroke-width="3"/>')
    s.append(arm(f"M{cx-66},402 Q{cx-96},430 {cx-114},452",BK))
    s.append(f'<circle cx="{(255+128+cx-114)//2}" cy="458" r="17" fill="{SK}" {ST}/>')  # joined hands
    if mood in ('sad','sleepy','thinking'):
        s.append(arm(f"M{cx+66},402 Q{cx+100},440 {cx+94},480",BK)+f'<circle cx="{cx+94}" cy="488" r="16" fill="{SK}" {ST}/>')
    else:
        s.append(arm(f"M{cx+66},398 Q{cx+104},380 {cx+106},330",BK)+f'<circle cx="{cx+106}" cy="320" r="16" fill="{SK}" {ST}/>')
    if mood=='happy':
        s.append(f'<path d="M{cx+130},300 q8,-4 12,2 M{cx+134},322 q10,0 12,6" stroke="{O}" stroke-width="3.5" fill="none" stroke-linecap="round"/>')
    for x,sg in ((-104,-1),(104,1)):
        s.append(f'<ellipse cx="{cx+x}" cy="236" rx="19" ry="25" fill="{SK}" {ST}/><path d="M{cx+x+sg*-2},224 q{sg*10},12 0,24" stroke="{SKS}" stroke-width="4" fill="none" stroke-linecap="round"/>')
    face=f"M{cx-102},226 C{cx-102},150 {cx-58},112 {cx},112 C{cx+58},112 {cx+102},150 {cx+102},226 C{cx+102},300 {cx+56},344 {cx},346 C{cx-56},344 {cx-102},300 {cx-102},226Z"
    s.append(f'<clipPath id="fh"><path d="{face}"/></clipPath><path d="{face}" fill="{SK}"/>')
    s.append(f'<g clip-path="url(#fh)"><path d="M{cx+56},110 C{cx+120},170 {cx+110},300 {cx+40},356 L{cx+120},356 L{cx+120},110Z" fill="{SKS}" opacity=".45"/></g>')
    s.append(f'<path d="{face}" fill="none" {ST}/>')
    hair=(f"M{cx-108},222 C{cx-122},140 {cx-80},78 {cx-10},70 C{cx+30},50 {cx+110},62 {cx+122},130 C{cx+130},170 {cx+118},200 {cx+104},222 "
          f"C{cx+100},190 {cx+92},170 {cx+80},160 C{cx+60},172 {cx+30},170 {cx+8},156 C{cx-14},172 {cx-50},170 {cx-70},156 C{cx-88},170 {cx-100},194 {cx-108},222Z")
    s.append(f'<clipPath id="fhr"><path d="{hair}"/></clipPath><path d="{hair}" fill="{HA}" {ST}/>')
    s.append(f'<g clip-path="url(#fhr)"><path d="M{cx+70},60 C{cx+130},90 {cx+130},170 {cx+104},224 L{cx+150},224 L{cx+150},50Z" fill="{HAD}" opacity=".55"/></g>')
    for d in (f"M{cx-60},100 C{cx-10},76 {cx+60},78 {cx+100},116",f"M{cx-70},126 C{cx-20},104 {cx+50},106 {cx+90},140",f"M{cx-20},84 C{cx+20},72 {cx+70},80 {cx+98},100"):
        s.append(f'<path d="{d}" stroke="{HAL}" stroke-width="5" fill="none" stroke-linecap="round"/>')
    if mood=='sad': s.append(f'<path d="M{cx-62},188 C{cx-50},188 {cx-30},182 {cx-18},172 M{cx+62},188 C{cx+50},188 {cx+30},182 {cx+18},172" stroke="{HA}" stroke-width="8" fill="none" stroke-linecap="round"/>')
    else: s.append(f'<path d="M{cx-64},192 C{cx-52},182 {cx-30},182 {cx-18},188 M{cx+64},192 C{cx+52},182 {cx+30},182 {cx+18},188" stroke="{HA}" stroke-width="8" fill="none" stroke-linecap="round"/>')
    s.append(eyes(cx,230,FE,14,17,40,mood))
    for i in range(14):
        side=R.choice((-1,1)); x=cx+side*R.uniform(30,66); y=R.uniform(256,276)
        s.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{R.uniform(1.8,2.8):.1f}" fill="#C98463"/>')
    s.append(f'<ellipse cx="{cx-64}" cy="276" rx="18" ry="10" fill="#F59A94" opacity=".5"/><ellipse cx="{cx+64}" cy="276" rx="18" ry="10" fill="#F59A94" opacity=".5"/>')
    s.append(f'<path d="M{cx-10},256 C{cx-14},270 {cx-4},274 {cx},272 C{cx+4},274 {cx+14},270 {cx+10},256" fill="{SKS}" stroke="{O}" stroke-width="3.5" stroke-linecap="round"/>')
    s.append(f'<path d="M{cx-11},269 a3.6,3.6 0 1 0 4,5" stroke="#B9BEC4" stroke-width="1.8" fill="none" stroke-linecap="round"/>')
    s.append(mouth(cx,294,mood,22))
    return "".join(s)


def eyes(cx,y,iris,rx,ry,dx,mood):
    if mood=='love':
        return "".join(f'<path d="M{cx+d-13},{y+4} Q{cx+d},{y-14} {cx+d+13},{y+4}" stroke="#1C1310" stroke-width="6" fill="none" stroke-linecap="round"/>' for d in (-dx,dx))
    if mood=='sleepy':
        return "".join(f'<path d="M{cx+d-13},{y} Q{cx+d},{y+8} {cx+d+13},{y}" stroke="#1C1310" stroke-width="5.5" fill="none" stroke-linecap="round"/>' for d in (-dx,dx))
    s=eye(cx-dx,y,iris,rx,ry)+eye(cx+dx,y,iris,rx,ry)
    if mood=='sad':
        s+=f'<path d="M{cx+dx+8},{y+18} q-7,12 0,16 q7,-4 0,-16Z" fill="#8FD0F5" stroke="#4A9BD0" stroke-width="2"/>'
    return s

def mouth(cx,y,mood,w):
    if mood=='sleepy':
        return f'<ellipse cx="{cx}" cy="{y+8}" rx="9" ry="11" fill="#8E3B3B" stroke="{O}" stroke-width="3.5"/>'
    if mood=='thinking':
        return f'<path d="M{cx-12},{y+8} q6,-5 12,0 q6,5 12,0" stroke="{O}" stroke-width="4" fill="none" stroke-linecap="round"/>'
    if mood=='sad':
        return f'<path d="M{cx-16},{y+14} Q{cx},{y} {cx+16},{y+14}" stroke="{O}" stroke-width="4.5" fill="none" stroke-linecap="round"/>'
    s=(f'<path d="M{cx-w},{y} C{cx-10},{y+4} {cx+10},{y+4} {cx+w},{y} C{cx+w-4},{y+26} {cx-w+4},{y+26} {cx-w},{y}Z" fill="#8E3B3B" stroke="{O}" stroke-width="3.5" stroke-linejoin="round"/>'
       f'<path d="M{cx-12},{y+16} C{cx-4},{y+10} {cx+4},{y+10} {cx+12},{y+16} C{cx+6},{y+21} {cx-6},{y+21} {cx-12},{y+16}Z" fill="#F08B8B"/>')
    if mood=='hungry':
        s+=f'<path d="M{cx+w-6},{y+10} q-6,14 0,20 q7,-6 0,-20Z" fill="#AEE0FA" stroke="#4A9BD0" stroke-width="2"/>'
    return s

def sparkle(x,y,r,c="#FFD54F"):
    return f'<path d="M{x},{y-r} Q{x+r*.18},{y-r*.18} {x+r},{y} Q{x+r*.18},{y+r*.18} {x},{y+r} Q{x-r*.18},{y+r*.18} {x-r},{y} Q{x-r*.18},{y-r*.18} {x},{y-r}Z" fill="{c}" stroke="#C9A227" stroke-width="2"/>'

KH=(147,488)   # Kevin free hand
FH=(611,320)   # Fritzi raised hand
def props(mood):
    s=""
    k=f'stroke="{O}" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"'
    if mood=='love':
        s+=heart(150,130,1.6)+heart(620,110,1.4,"#F07C80")+heart(660,220,1.0)
    if mood=='sleepy':
        s+='<text x="620" y="150" font-family="Arial Rounded MT Bold, Arial, sans-serif" font-weight="700" font-size="44" fill="#5C6BC0">Z</text><text x="660" y="110" font-family="Arial, sans-serif" font-weight="700" font-size="32" fill="#7986CB">z</text><text x="690" y="80" font-family="Arial, sans-serif" font-weight="700" font-size="24" fill="#9FA8DA">z</text>'
        s+='<path d="M90,120 a34,34 0 1 0 40,46 a28,28 0 1 1 -40,-46Z" fill="#FFE08A" stroke="#C9A227" stroke-width="3"/>'
    if mood=='hungry':
        x,y=FH; s+=f'<path d="M{x+4},{y-60} v44" stroke="#9AA3AD" stroke-width="7" stroke-linecap="round"/><path d="M{x-8},{y-62} v18 q0,10 12,10 q12,0 12,-10 v-18" stroke="#9AA3AD" stroke-width="5" fill="none" stroke-linecap="round"/>'
        s+=f'<g transform="translate(110 110)"><path d="M-46,0 h92 q-6,40 -46,40 q-40,0 -46,-40Z" fill="#F4F4F4" {k}/><path d="M-30,-4 q8,-26 22,-6 q10,-24 24,-2 q14,-18 20,8Z" fill="#F0A24A" {k}/><path d="M-12,-30 q-6,-12 0,-22 M8,-30 q-6,-12 0,-22" stroke="#B0B7BF" stroke-width="3" fill="none" stroke-linecap="round"/></g>'
    if mood=='shopping':
        x,y=KH; s+=f'<path d="M{x-18},{y-2} q18,-36 36,0" stroke="{O}" stroke-width="5" fill="none"/><path d="M{x-40},{y} h80 l-8,72 h-64Z" fill="#F2D3A0" {k}/><path d="M{x-30},{y+4} q-6,-26 8,-30 M{x+14},{y+4} q2,-28 18,-26" stroke="#4CAF50" stroke-width="7" fill="none" stroke-linecap="round"/><circle cx="{x+30}" cy="{y-26}" r="10" fill="#E53935" {k}/>'
    if mood=='cleaning':
        s+=sparkle(120,150,22)+sparkle(160,230,12)+sparkle(650,140,18)+sparkle(690,250,12,"#B3E5FC")
        x,y=FH; s+=f'<rect x="{x-20}" y="{y-60}" width="40" height="34" rx="8" fill="#FFD54F" {k}/><rect x="{x-20}" y="{y-38}" width="40" height="12" rx="4" fill="#66BB6A" stroke="{O}" stroke-width="3"/>'
        for bx,by,br in ((x-30,y-78,9),(x+2,y-92,12),(x+28,y-74,7)): s+=f'<circle cx="{bx}" cy="{by}" r="{br}" fill="#E1F5FE" stroke="#81D4FA" stroke-width="2.5"/>'
    if mood=='money':
        x,y=FH; s+=f'<circle cx="{x}" cy="{y-46}" r="30" fill="#FFCA28" {k}/><circle cx="{x}" cy="{y-46}" r="22" fill="none" stroke="#E0A800" stroke-width="3"/><text x="{x}" y="{y-35}" font-family="Arial, sans-serif" font-weight="700" font-size="30" text-anchor="middle" fill="#9A6B00">€</text>'
        s+=sparkle(x+44,y-80,10)
    if mood=='calendar':
        x,y=FH; s+=f'<g transform="rotate(8 {x} {y-60})"><rect x="{x-38}" y="{y-104}" width="76" height="80" rx="10" fill="#fff" {k}/><path d="M{x-38},{y-94} q0,-10 10,-10 h56 q10,0 10,10 v14 h-76Z" fill="#E53935" {k}/><text x="{x}" y="{y-36}" font-family="Arial, sans-serif" font-weight="700" font-size="34" text-anchor="middle" fill="{O}">12</text></g>'
    if mood=='travel':
        x,y=KH; s+=f'<rect x="{x-48}" y="{y+6}" width="72" height="56" rx="10" fill="#FF8A65" {k}/><path d="M{x-28},{y+6} v-14 h32 v14" stroke="{O}" stroke-width="5" fill="none"/><path d="M{x-30},{y+6} v56 M{x+6},{y+6} v56" stroke="#D84315" stroke-width="4"/>'
        s+='<path d="M600,120 l70,-20 q14,-2 12,10 l-58,30 l-8,26 l-10,4 l0,-24 l-26,10 l-6,-6 Z" fill="#fff" stroke="#3B2418" stroke-width="3.5" stroke-linejoin="round"/>'
    if mood=='care':
        x,y=KH; s+=f'<g transform="translate({x-6} {y+8})"><path d="M-30,0 h50 v40 q0,10 -10,10 h-30 q-10,0 -10,-10Z" fill="#4FC3F7" {k}/><path d="M20,10 l36,-24 l6,6 l-34,28" fill="#4FC3F7" {k}/><path d="M-30,10 q-22,4 -18,24" stroke="{O}" stroke-width="5" fill="none"/></g>'
        s+=f'<g transform="translate(675 520)"><path d="M-26,0 h52 l-8,36 h-36Z" fill="#D27A4A" {k}/><path d="M0,0 q-4,-40 -30,-50 q20,-4 32,26 q6,-40 34,-40 q-10,30 -34,64" fill="#4CAF50" {k}/></g>'
        x,y=FH; s+=f'<g transform="rotate(-30 {x} {y-40})"><rect x="{x-34}" y="{y-54}" width="68" height="28" rx="14" fill="#F3C9A0" {k}/><rect x="{x-12}" y="{y-54}" width="24" height="28" fill="#E8B48A" stroke="{O}" stroke-width="3"/><circle cx="{x-4}" cy="{y-44}" r="2" fill="{O}"/><circle cx="{x+4}" cy="{y-36}" r="2" fill="{O}"/></g>'
    if mood=='thinking':
        s+=f'<path d="M560,40 h100 q20,0 20,20 v50 q0,20 -20,20 h-100 q-20,0 -20,-20 v-50 q0,-20 20,-20Z" fill="#fff" {k}/><circle cx="560" cy="150" r="9" fill="#fff" {k}/><circle cx="545" cy="172" r="5" fill="#fff" stroke="{O}" stroke-width="3"/><text x="610" y="106" font-family="Arial, sans-serif" font-weight="700" font-size="54" text-anchor="middle" fill="#43A047">?</text>'
    if mood=='sad':
        s+='<path d="M80,110 q0,-30 34,-30 q10,-26 40,-20 q30,-8 40,20 q34,0 30,30 q0,20 -26,20 h-92 q-26,0 -26,-20Z" fill="#B0BEC5" stroke="#78909C" stroke-width="3"/>'
        for dx in (110,140,170): s+=f'<path d="M{dx},150 l-6,16" stroke="#64B5F6" stroke-width="4" stroke-linecap="round"/>'
    if mood=='happy':
        s+=heart(380,58,2.2)+heart(340,96,1.1,"#F07C80")
    return s

def scene(mood, bgc=("#E7F4E4","#CDE6CB")):
    bg=(f'<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{bgc[0]}"/><stop offset="1" stop-color="{bgc[1]}"/></linearGradient>'
        '<clipPath id="card"><rect width="760" height="600" rx="32"/></clipPath></defs>'
        '<g clip-path="url(#card)"><rect width="760" height="600" fill="url(#bg)"/><circle cx="380" cy="300" r="250" fill="#BCDDBB" opacity=".55"/>'
        '<ellipse cx="380" cy="560" rx="300" ry="22" fill="#B2D6B0"/>')
    sun='<circle cx="680" cy="80" r="38" fill="#F6D58E"/>' if mood=='happy' else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 760 600" width="760" height="600">{bg}{sun}'
            f'{fritzi(mood=mood)}{kevin(mood=mood)}{props(mood)}</g></svg>')

MOODS=[('happy','fröhlich'),('love','verliebt'),('sleepy','müde'),('hungry','hungrig'),('shopping','Einkaufen'),('cleaning','Putzen'),
       ('money','Finanzen'),('calendar','Kalender'),('travel','Reisen'),('care','Tiere & Pflanzen'),('thinking','nachdenklich'),('sad','traurig')]
# ---- Export for the app ----
def app_svg(mood, only=None, vb="0 20 760 550"):
    shadow='<ellipse cx="380" cy="556" rx="250" ry="14" fill="#000" opacity=".12"/>'
    R.seed(7)
    if only=='dudu':
        body=f'<ellipse cx="255" cy="556" rx="120" ry="12" fill="#000" opacity=".12"/>{kevin(mood=mood)}'; vb="90 20 330 550"
    elif only=='bubu':
        body=f'<ellipse cx="505" cy="556" rx="110" ry="12" fill="#000" opacity=".12"/>{fritzi(mood=mood)}'; vb="345 20 320 550"
    else:
        body=f'{shadow}{fritzi(mood=mood)}{kevin(mood=mood)}{props(mood)}'
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" width="{vb.split()[2]}" height="{vb.split()[3]}">{body}</svg>'

def logo_svg(fg=False):
    R.seed(7)
    if fg:
        vb="20 -40 720 720"; bg=""
    else:
        vb="100 20 560 560"; bg='<rect x="0" y="-100" width="760" height="800" fill="#1B5E20"/>'
    hearts=heart(380,70,2.4)+heart(330,112,1.2,"#F07C80")
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" width="1024" height="1024">{bg}{fritzi(mood="love")}{kevin(mood="love")}{hearts}</svg>'

def export(out):
    import os; os.makedirs(out+'/mascots',exist_ok=True); os.makedirs(out+'/logo',exist_ok=True)
    for m,_ in MOODS: open(f'{out}/mascots/{m}.svg','w').write(app_svg(m))
    open(f'{out}/mascots/dudu.svg','w').write(app_svg('happy','dudu'))
    open(f'{out}/mascots/bubu.svg','w').write(app_svg('happy','bubu'))
    open(f'{out}/logo/logo.svg','w').write(logo_svg())
    open(f'{out}/logo/logo_foreground.svg','w').write(logo_svg(True))
