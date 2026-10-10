"""Author SVG construction guides. These are diagrams, never game sprites."""
from pathlib import Path
import math
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art_source/动作重绘"
OUT.mkdir(parents=True, exist_ok=True)

def knee(h, a, length=26.5):
    dx,dy=a[0]-h[0],a[1]-h[1]
    d=math.hypot(dx,dy)
    height=math.sqrt(max(0,length*length-d*d/4))
    return ((h[0]+a[0])/2+height*dy/max(d,1),(h[1]+a[1])/2-height*dx/max(d,1))

fwd=[26,13,0,-13,-26,-13,0,13]
lift=[0,0,0,0,0,12,20,12]
bob=[0,4,-7,-8,0,4,-7,-8]
names=["Contact A forward","Down A support","Passing B raised","Up B forward","Contact B forward","Down B support","Passing A raised","Up A forward"]
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1536" height="1024" viewBox="0 0 1536 1024">','<rect width="1536" height="1024" fill="#f4f7f9"/>']
for frame in range(8):
    ox=(frame%4)*384;oy=(frame//4)*512
    svg.append(f'<g transform="translate({ox},{oy})">')
    svg.append('<rect x="1" y="1" width="382" height="510" fill="none" stroke="#bed0da"/>')
    svg.append(f'<text x="20" y="28" font-size="17" font-family="sans-serif" fill="#294359">{frame+1:02d} {names[frame]}</text>')
    svg.append('<path d="M34 420H350M192 45V455" stroke="#afbdc7" stroke-dasharray="5 5" fill="none"/>')
    for leg in [1,0]:
        phase=(frame+leg*4)%8
        lane=5 if leg==0 else -5
        color="#d74f5f" if leg==0 else "#4b87bd"
        h=(192,364+bob[frame]+lane)
        heel_rise=4 if phase==3 else 0
        ankle=(192+fwd[phase],420+lane-lift[phase]-heel_rise-10)
        k=knee(h,ankle)
        svg.append(f'<path d="M{h[0]} {h[1]} L{k[0]:.1f} {k[1]:.1f} L{ankle[0]} {ankle[1]}" fill="none" stroke="{color}" stroke-width="11" stroke-linecap="round" stroke-linejoin="round"/>')
        toe=ankle[1]+10+heel_rise
        svg.append(f'<path d="M{ankle[0]-5} {ankle[1]+3} Q{ankle[0]+7} {ankle[1]} {ankle[0]+17} {toe-4} L{ankle[0]+17} {toe} L{ankle[0]-5} {ankle[1]+10}Z" fill="{color}"/>')
    # A readable chibi proportion and intact skirt cover the hip joints.
    b=bob[frame]
    svg.append(f'<path d="M148 {238+b} Q192 {222+b} 230 {242+b} L250 {376+b} Q192 {395+b} 134 {376+b}Z" fill="#e7edf0" stroke="#657581" stroke-width="3"/>')
    svg.append(f'<ellipse cx="187" cy="145" rx="78" ry="82" transform="translate(0,{b})" fill="#e7edf0" stroke="#657581" stroke-width="3"/>')
    svg.append(f'<path d="M233 {129+b}L257 {154+b}L237 {160+b}" fill="none" stroke="#657581" stroke-width="3"/>')
    svg.append(f'<circle cx="233" cy="137" r="5" transform="translate(0,{b})" fill="#657581"/>')
    for arm in [1,0]:
        p=(frame+arm*4)%8
        color="#d74f5f" if arm==0 else "#4b87bd"
        handx=192-fwd[p]*.65
        svg.append(f'<path d="M192 {252+b} L{handx:.1f} {321+b}" fill="none" stroke="{color}" stroke-width="10" stroke-linecap="round"/>')
    svg.append('<circle cx="192" cy="420" r="3" fill="#294359"/><text x="20" y="478" font-size="14" font-family="sans-serif" fill="#516779">Red = near leg A; blue = far leg B</text></g>')
svg.append('</svg>')
(OUT/'right_8poses_guide.svg').write_text(''.join(svg),encoding='utf-8')
single=''.join(svg).replace('width="1536" height="1024" viewBox="0 0 1536 1024"','width="384" height="512" viewBox="0 512 384 512"',1)
(OUT/'right_contact_B_guide.svg').write_text(single,encoding='utf-8')
print('NATIVE SVG WALK CONSTRUCTION GUIDE WRITTEN')
