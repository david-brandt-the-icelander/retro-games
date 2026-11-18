#!/usr/bin/env python3
"""Generates every piece of artwork for Inkwell Academy as SVG (all original).

Characters are cut-out rigs (thigh, shin, torso, arm, head, optional gown) so Godot
can animate them smoothly. Run from the project root:  python3 tools/make_art.py
"""
import json, math, os, random

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot')
ART = os.path.join(ROOT, 'art')
CH = os.path.join(ART, 'chars')
os.makedirs(CH, exist_ok=True)

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate={mip}
svg/scale=1.0
process/fix_alpha_border=true
"""


def write_svg(path, w, h, body, scale=2.0, defs='', mip=True):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*scale:.0f}" height="{h*scale:.0f}" '
           f'viewBox="0 0 {w} {h}"><defs>{defs}</defs>{body}</svg>')
    with open(path, 'w') as f:
        f.write(svg)
    imp = path + '.import'
    with open(imp, 'w') as f:
        f.write(IMPORT.format(mip='true' if mip else 'false'))


# ---------------------------------------------------------------- colour helpers
def hx(c):
    c = c.lstrip('#')
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def to_hex(t):
    return '#%02x%02x%02x' % tuple(max(0, min(255, round(v))) for v in t)


def shade(c, f):
    r, g, b = hx(c)
    if f >= 1:
        return to_hex((r + (255 - r) * (f - 1), g + (255 - g) * (f - 1), b + (255 - b) * (f - 1)))
    return to_hex((r * f, g * f, b * f))


def mix(a, b, t):
    A, B = hx(a), hx(b)
    return to_hex(tuple(A[i] + (B[i] - A[i]) * t for i in range(3)))


_gid = [0]


def lin(c1, c2, x1=0, y1=0, x2=0, y2=1, stops=None):
    _gid[0] += 1
    gid = f'g{_gid[0]}'
    st = stops or [(0, c1, 1), (1, c2, 1)]
    s = ''.join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in st)
    return gid, f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def rad(stops, cx=0.5, cy=0.5, r=0.5, user=None):
    _gid[0] += 1
    gid = f'g{_gid[0]}'
    s = ''.join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
    if user:
        ux, uy, ur = user
        return gid, f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" cx="{ux}" cy="{uy}" r="{ur}">{s}</radialGradient>'
    return gid, f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">{s}</radialGradient>'


INK = '#2b2233'   # outline colour used everywhere
OL = f'stroke="{INK}" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"'

# ---------------------------------------------------------------- character parts
# All parts drawn facing right.  Each returns (w, h, pivot, defs, body).


def part_thigh(L, w, col, skirt=False):
    W, H = w + 4, L + w + 4
    gid, d = lin(shade(col, 1.12), shade(col, 0.88), 0, 0, 1, 0)
    body = f'<rect x="2" y="2" width="{w}" height="{L + w}" rx="{w / 2}" fill="url(#{gid})" {OL}/>'
    return W, H, (2 + w / 2, 2 + w / 2), d, body


def part_shin(L, w, col, shoe, sock=None, skin=None):
    # pivot = knee; sole is at pivot + L
    W, H = w + 22, L + w / 2 + 4
    px, py = 2 + w / 2, 2 + w / 2
    sole = py + L
    gid, d = lin(shade(col, 1.12), shade(col, 0.88), 0, 0, 1, 0)
    body = f'<rect x="2" y="2" width="{w}" height="{L - 4}" rx="{w / 2}" fill="url(#{gid})" {OL}/>'
    if sock:
        body += f'<rect x="2.4" y="{py + L * 0.45}" width="{w - 0.8}" height="{L * 0.45}" rx="2" fill="{sock}" {OL}/>'
    sh = shoe
    tl = w + 14
    body += (f'<path d="M1.5,{sole - 9} Q1.5,{sole - 12} {w * 0.6},{sole - 12} L{tl - 8},{sole - 10} '
             f'Q{tl},{sole - 9} {tl},{sole - 3} L{tl},{sole} L1.5,{sole} Z" fill="{sh}" {OL}/>'
             f'<path d="M{w * 0.6},{sole - 9.5} L{tl - 8},{sole - 8}" stroke="{shade(sh, 1.6)}" stroke-width="1.4" stroke-linecap="round"/>')
    return W, H + 2, (px, py), d, body


def part_arm(L, w, sleeve, skin, cuff=None):
    W, H = w + 6, L + w + 8
    px, py = 3 + w / 2, 3 + w / 2
    gid, d = lin(shade(sleeve, 1.1), shade(sleeve, 0.85), 0, 0, 1, 0)
    hand_r = w * 0.52
    body = f'<rect x="3" y="3" width="{w}" height="{L - hand_r * 0.6}" rx="{w / 2}" fill="url(#{gid})" {OL}/>'
    if cuff:
        body += f'<rect x="3" y="{py + L - hand_r * 2.1}" width="{w}" height="{hand_r * 0.9}" rx="2" fill="{cuff}" {OL}/>'
    body += f'<circle cx="{px}" cy="{py + L}" r="{hand_r}" fill="{skin}" {OL}/>'
    return W, H, (px, py), d, body


def part_torso(style, w, h, pal, skirt_len=0):
    """pivot at hip centre (bottom).  style: jumper | jacket | dress | labcoat | suit"""
    pad = 4
    W = w + pad * 2 + 16
    H = h + pad * 2 + skirt_len
    cx, hip = W / 2, pad + h
    top = pad
    defs = ''
    b = ''
    main = pal['T']
    gid, d = lin(shade(main, 1.12), shade(main, 0.85), 0, 0, 1, 0.3)
    defs += d
    # body shape: shoulders rounded, slightly narrower at the waist
    sx = w / 2
    path = (f'M{cx - sx + 3},{top + 7} Q{cx - sx + 3},{top} {cx - sx + 10},{top} L{cx + sx - 10},{top} '
            f'Q{cx + sx - 2},{top} {cx + sx - 2},{top + 8} L{cx + sx - 1},{hip - 4} Q{cx + sx - 1},{hip} {cx + sx - 5},{hip} '
            f'L{cx - sx + 5},{hip} Q{cx - sx + 1},{hip} {cx - sx + 1},{hip - 4} Z')
    if style in ('dress', 'labcoat') and skirt_len:
        sk = pal.get('D', main)
        gid2, d2 = lin(shade(sk, 1.1), shade(sk, 0.8), 0, 0, 1, 0.2)
        defs += d2
        b += (f'<path d="M{cx - sx + 1},{hip - 6} L{cx + sx - 1},{hip - 6} L{cx + sx + 7},{hip + skirt_len - 3} '
              f'Q{cx},{hip + skirt_len + 3} {cx - sx - 7},{hip + skirt_len - 3} Z" fill="url(#{gid2})" {OL}/>')
    if style == 'labcoat':
        coat = '#f4f6f8'
        gid3, d3 = lin('#ffffff', '#cfd6de', 0, 0, 1, 0.2)
        defs += d3
        b += (f'<path d="M{cx - sx + 3},{top + 7} Q{cx - sx + 3},{top} {cx - sx + 10},{top} L{cx + sx - 10},{top} '
              f'Q{cx + sx - 2},{top} {cx + sx - 2},{top + 8} L{cx + sx + 2},{hip + skirt_len * 0.55} L{cx - sx - 2},{hip + skirt_len * 0.55} Z" '
              f'fill="url(#{gid3})" {OL}/>')
        b += (f'<path d="M{cx - 2},{top} L{cx + 3},{top + 14} L{cx + 8},{top}" fill="{pal["D"]}" {OL}/>'
              f'<line x1="{cx + 3}" y1="{top + 14}" x2="{cx + 3}" y2="{hip + skirt_len * 0.5}" stroke="{INK}" stroke-width="1.2"/>'
              f'<rect x="{cx + 6}" y="{top + 18}" width="8" height="9" rx="1.5" fill="#e3e8ee" {OL}/>'
              f'<line x1="{cx + 9}" y1="{top + 15}" x2="{cx + 9}" y2="{top + 21}" stroke="#3a7bd5" stroke-width="2" stroke-linecap="round"/>')
        return W, H, (cx, hip), defs, b
    b += f'<path d="{path}" fill="url(#{gid})" {OL}/>'
    if style == 'jumper':
        b += (f'<path d="M{cx - 6},{top} L{cx},{top + 9} L{cx + 6},{top} Z" fill="#ffffff" {OL}/>'
              f'<path d="M{cx - 2},{top + 3} L{cx + 2},{top + 3} L{cx + 1},{top + 8} L{cx - 1},{top + 8} Z" fill="{pal.get("tie", "#c0392b")}"/>'
              f'<rect x="{cx - sx + 1.5}" y="{hip - 6}" width="{w - 3}" height="5" rx="2" fill="{shade(main, 0.78)}"/>'
              f'<path d="M{cx + sx - 11},{top + 15} q4,3 8,0" stroke="{shade(main, 0.7)}" stroke-width="1.3" fill="none"/>')
        if pal.get('badge'):
            b += f'<circle cx="{cx + 7}" cy="{top + 15}" r="3" fill="{pal["badge"]}" {OL}/>'
    elif style == 'jacket':
        b += (f'<path d="M{cx - 7},{top} L{cx + 7},{top} L{cx + 4},{hip - 2} L{cx - 4},{hip - 2} Z" fill="#fbf7ee" {OL}/>'
              f'<path d="M{cx - 2},{top + 2} L{cx + 2},{top + 2} L{cx + 3},{top + 26} L{cx},{top + 30} L{cx - 3},{top + 26} Z" fill="{pal.get("tie", "#b03030")}" {OL}/>'
              f'<path d="M{cx - 7},{top} L{cx - 1},{top + 22} L{cx - 4},{hip}" stroke="{INK}" stroke-width="1.4" fill="none"/>'
              f'<path d="M{cx + 7},{top} L{cx + 4},{top + 20} L{cx + 6},{hip}" stroke="{INK}" stroke-width="1.4" fill="none"/>'
              f'<circle cx="{cx + 7}" cy="{hip - 16}" r="1.6" fill="{INK}"/><circle cx="{cx + 7}" cy="{hip - 8}" r="1.6" fill="{INK}"/>'
              f'<rect x="{cx + sx - 13}" y="{top + 12}" width="9" height="2" rx="1" fill="{shade(main, 0.7)}"/>')
    elif style == 'dress':
        b += (f'<path d="M{cx - 9},{top} Q{cx},{top + 9} {cx + 9},{top}" fill="{pal["S"]}" {OL}/>')
        for i in range(7):
            a = math.pi * (0.15 + 0.7 * i / 6)
            b += f'<circle cx="{cx - math.cos(a) * 9:.1f}" cy="{top + math.sin(a) * 8 + 1:.1f}" r="1.5" fill="#fffaf0" stroke="{INK}" stroke-width=".6"/>'
        if pal.get('cardigan'):
            cg = pal['cardigan']
            b += (f'<path d="M{cx - sx + 3},{top + 7} Q{cx - sx + 3},{top} {cx - sx + 10},{top} L{cx - 4},{top} L{cx - 2},{hip + 6} L{cx - sx - 1},{hip + 6} Z" fill="{cg}" {OL}/>'
                  f'<path d="M{cx + 8},{top} L{cx + sx - 8},{top} Q{cx + sx - 2},{top} {cx + sx - 2},{top + 8} L{cx + sx + 1},{hip + 6} L{cx + 5},{hip + 6} Z" fill="{cg}" {OL}/>')
            for yy in (top + 14, top + 24, top + 34):
                b += f'<circle cx="{cx + 7}" cy="{yy}" r="1.4" fill="#f4e4c0" stroke="{INK}" stroke-width=".6"/>'
    elif style == 'suit':
        b += (f'<path d="M{cx - 6},{top} L{cx + 6},{top} L{cx + 3},{top + 18} L{cx - 3},{top + 18} Z" fill="#fbf7ee" {OL}/>'
              f'<path d="M{cx - 5},{top + 3} L{cx},{top + 6} L{cx + 5},{top + 3} L{cx + 5},{top + 9} L{cx},{top + 6} L{cx - 5},{top + 9} Z" fill="{pal.get("tie", "#e0b030")}" {OL}/>'
              f'<rect x="{cx - 1}" y="{top + 22}" width="2" height="2" rx="1" fill="{pal.get("tie", "#e0b030")}"/>'
              f'<path d="M{cx + 2},{top + 26} q6,4 10,0" stroke="#e0b030" stroke-width="1.2" fill="none"/>')
    return W, H, (cx, hip), defs, b


def part_gown(w, h, col, trim):
    W, H = w + 12, h + 6
    cx = W / 2
    gid, d = lin(shade(col, 1.25), shade(col, 0.8), 0, 0, 1, 0.3)
    body = (f'<path d="M{cx - w * 0.32},3 L{cx + w * 0.32},3 Q{cx + w * 0.5},{h * 0.5} {cx + w * 0.5 + 4},{h} '
            f'Q{cx},{h + 4} {cx - w * 0.5 - 4},{h} Q{cx - w * 0.5},{h * 0.5} {cx - w * 0.32},3 Z" fill="url(#{gid})" {OL}/>'
            f'<path d="M{cx + w * 0.3},4 Q{cx + w * 0.45},{h * 0.5} {cx + w * 0.46},{h - 2}" stroke="{trim}" stroke-width="3" fill="none"/>')
    return W, H, (cx, 5), d, body


def part_head(p):
    """Head facing right; pivot at bottom of neck. p: dict of features."""
    W, H = 52, 66
    oy = 10  # headroom for hats / buns
    skin, hair = p['skin'], p['hair']
    cx, cy, r = 25, 24 + oy, 16
    d = ''
    gid, dd = rad([(0, shade(skin, 1.08), 1), (1, shade(skin, 0.9), 1)], 0.6, 0.35, 0.75)
    d += dd
    hg, dd = lin(shade(hair, 1.25), shade(hair, 0.85), 0, 0, 0.3, 1)
    d += dd
    b = ''
    style = p.get('style', 'short')
    # behind-face hair
    if style in ('bob', 'long'):
        ln = 22 if style == 'bob' else 34
        b += f'<path d="M6,{cy - 6} Q4,{cy - 21} {cx - 2},{cy - 21} Q{cx + 16},{cy - 21} {cx + 14},{cy - 4} L{cx - 2},{cy + ln - 8} Q{cx - 10},{cy + ln} 4,{cy + ln - 2} Q1,{cy + 8} 6,{cy - 6} Z" fill="url(#{hg})" {OL}/>'
    if style == 'pony':
        b += f'<path d="M7,{cy - 6} Q-2,{cy} 1,{cy + 16} Q6,{cy + 8} 10,{cy - 2} Z" fill="url(#{hg})" {OL}/>'
        b += f'<circle cx="7" cy="{cy - 5}" r="3" fill="{p.get("bow", "#e74c3c")}" {OL}/>'
    if style == 'bun':
        b += f'<circle cx="{cx - 9}" cy="{cy - 17}" r="8" fill="url(#{hg})" {OL}/>'
        b += f'<path d="M{cx - 15},{cy - 21} q6,-2 11,3" stroke="{shade(hair, 0.7)}" stroke-width="1" fill="none"/>'
    if style == 'curly':
        for (x, y, rr) in [(9, cy - 10, 7), (14, cy - 18, 7), (23, cy - 21, 7), (32, cy - 19, 6), (6, cy, 6), (10, cy + 6, 5)]:
            b += f'<circle cx="{x}" cy="{y}" r="{rr}" fill="url(#{hg})" {OL}/>'
    # neck
    b += f'<rect x="{cx - 6}" y="{cy + 10}" width="11" height="{H - (cy + 10) - 3}" rx="3" fill="{shade(skin, 0.86)}" {OL}/>'
    # back-of-head hair cap
    if style not in ('bald', 'curly'):
        b += f'<circle cx="{cx - 3}" cy="{cy - 3}" r="{r + 1.5}" fill="url(#{hg})" {OL}/>'
    elif style == 'bald':
        b += f'<path d="M{cx - 18},{cy + 2} Q{cx - 19},{cy - 9} {cx - 12},{cy - 13} L{cx - 9},{cy + 6} Z" fill="url(#{hg})" {OL}/>'
    # face
    b += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#{gid})" {OL}/>'
    # ear
    b += f'<ellipse cx="{cx - 6}" cy="{cy + 2}" rx="4" ry="5" fill="{shade(skin, 0.95)}" {OL}/><path d="M{cx - 7},{cy} q2,2 0,4" stroke="{shade(skin, 0.7)}" stroke-width="1" fill="none"/>'
    # nose
    b += f'<path d="M{cx + 14},{cy - 2} Q{cx + 20},{cy + 3} {cx + 14.5},{cy + 5}" fill="{shade(skin, 0.97)}" {OL}/>'
    # cheek
    b += f'<circle cx="{cx + 9}" cy="{cy + 6}" r="3.6" fill="#ff7f8a" opacity="0.35"/>'
    # eye + brow
    ex, ey = cx + 8, cy - 2
    b += f'<ellipse cx="{ex}" cy="{ey}" rx="3.1" ry="3.9" fill="#ffffff" stroke="{INK}" stroke-width="1"/>'
    b += f'<circle cx="{ex + 1}" cy="{ey + 0.6}" r="2.1" fill="{p.get("eye", "#3b2a1e")}"/><circle cx="{ex + 1.7}" cy="{ey - 0.4}" r=".8" fill="#fff"/>'
    brow = p.get('brow', shade(hair, 0.8))
    b += f'<path d="M{ex - 3},{ey - 6.5} Q{ex + 1},{ey - 9} {ex + 4},{ey - 6.5}" stroke="{brow}" stroke-width="2" fill="none" stroke-linecap="round"/>'
    # mouth
    if p.get('mood') == 'stern':
        b += f'<path d="M{cx + 6},{cy + 10} L{cx + 12},{cy + 9.5}" stroke="{INK}" stroke-width="1.6" stroke-linecap="round"/>'
    elif p.get('mood') == 'smirk':
        b += f'<path d="M{cx + 5},{cy + 9} Q{cx + 10},{cy + 11} {cx + 13},{cy + 7}" stroke="{INK}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
    else:
        b += f'<path d="M{cx + 5},{cy + 8.5} Q{cx + 9},{cy + 12.5} {cx + 13},{cy + 8.5}" stroke="{INK}" stroke-width="1.6" fill="#a8323e" stroke-linecap="round"/>'
    if p.get('freckles'):
        for (fx, fy) in [(cx + 6, cy + 4), (cx + 9, cy + 3), (cx + 11, cy + 5)]:
            b += f'<circle cx="{fx}" cy="{fy}" r=".7" fill="{shade(skin, 0.6)}"/>'
    # front hair / fringe
    if style == 'short' or style == 'pony':
        b += f'<path d="M{cx - 15},{cy - 3} Q{cx - 14},{cy - 18} {cx + 1},{cy - 18} Q{cx + 15},{cy - 17} {cx + 15},{cy - 7} Q{cx + 7},{cy - 12} {cx},{cy - 9} Q{cx - 5},{cy - 13} {cx - 9},{cy - 4} Z" fill="url(#{hg})" {OL}/>'
    elif style == 'spiky':
        b += (f'<path d="M{cx - 16},{cy - 1} L{cx - 17},{cy - 14} L{cx - 11},{cy - 12} L{cx - 9},{cy - 22} L{cx - 3},{cy - 16} L{cx + 2},{cy - 24} '
              f'L{cx + 6},{cy - 16} L{cx + 13},{cy - 20} L{cx + 12},{cy - 11} L{cx + 17},{cy - 8} Q{cx + 6},{cy - 11} {cx},{cy - 8} Q{cx - 6},{cy - 10} {cx - 9},{cy - 3} Z" fill="url(#{hg})" {OL}/>')
    elif style in ('bob', 'long'):
        b += f'<path d="M{cx - 15},{cy - 2} Q{cx - 14},{cy - 19} {cx + 2},{cy - 18} Q{cx + 15},{cy - 16} {cx + 15},{cy - 6} L{cx + 2},{cy - 9} Q{cx - 6},{cy - 10} {cx - 9},{cy - 1} Z" fill="url(#{hg})" {OL}/>'
    elif style == 'bun':
        b += f'<path d="M{cx - 15},{cy - 1} Q{cx - 14},{cy - 18} {cx + 2},{cy - 17} Q{cx + 14},{cy - 15} {cx + 14},{cy - 8} Q{cx + 4},{cy - 13} {cx - 2},{cy - 9} Q{cx - 7},{cy - 7} {cx - 9},{cy} Z" fill="url(#{hg})" {OL}/>'
    elif style == 'curly':
        for (x, y, rr) in [(cx - 6, cy - 14, 6), (cx + 2, cy - 16, 6), (cx + 9, cy - 13, 5)]:
            b += f'<circle cx="{x}" cy="{y}" r="{rr}" fill="url(#{hg})" {OL}/>'
    elif style == 'bald':
        b += f'<path d="M{cx - 12},{cy - 11} Q{cx - 2},{cy - 19} {cx + 9},{cy - 13}" stroke="#ffffff" stroke-width="2" opacity=".35" fill="none" stroke-linecap="round"/>'
    # extras
    if p.get('mustache'):
        mc = p['mustache']
        b += f'<path d="M{cx + 8},{cy + 7} Q{cx + 13},{cy + 3} {cx + 18},{cy + 7} Q{cx + 13},{cy + 7.5} {cx + 8},{cy + 7} Z" fill="{mc}" {OL}/>'
    if p.get('beard'):
        bc = p['beard']
        b += f'<path d="M{cx - 4},{cy + 7} Q{cx - 2},{cy + 22} {cx + 9},{cy + 21} Q{cx + 16},{cy + 18} {cx + 15},{cy + 9} Q{cx + 9},{cy + 13} {cx + 3},{cy + 11} Z" fill="{bc}" {OL}/>'
    if p.get('glasses'):
        g = p['glasses']
        b += (f'<circle cx="{ex + 0.5}" cy="{ey}" r="5.2" fill="#ffffff" fill-opacity=".25" stroke="{g}" stroke-width="1.6"/>'
              f'<path d="M{ex - 4.6},{ey - 1} L{cx - 4},{cy - 1}" stroke="{g}" stroke-width="1.5"/>')
    if p.get('mortarboard'):
        b += (f'<path d="M{cx - 14},{cy - 15} Q{cx},{cy - 22} {cx + 14},{cy - 15} L{cx + 13},{cy - 9} Q{cx},{cy - 15} {cx - 13},{cy - 9} Z" fill="#1d1a24" {OL}/>'
              f'<path d="M{cx - 22},{cy - 18} L{cx + 2},{cy - 27} L{cx + 24},{cy - 19} L{cx},{cy - 11} Z" fill="#2b2733" {OL}/>'
              f'<circle cx="{cx + 1}" cy="{cy - 19}" r="1.8" fill="#f2c230"/>'
              f'<path d="M{cx + 1},{cy - 19} Q{cx + 14},{cy - 18} {cx + 19},{cy - 9}" stroke="#f2c230" stroke-width="1.6" fill="none"/>'
              f'<path d="M{cx + 17},{cy - 9} l2,7 l3,-6 Z" fill="#f2c230"/>')
    pivot = (cx - 0.5, H - 3)
    return W, H, pivot, d, b


# ---------------------------------------------------------------- the cast (all original)
SK = ['#f6cfa5', '#e8b48a', '#c98d5e', '#8d5a3a', '#f3d6bd', '#b47a52']
CAST = {
    # id: (template, palette, head features)
    'pip':      ('kid', {'T': '#e8473c', 'L': '#2f4a8f', 'shoe': '#3a2a20', 'tie': '#2f4a8f', 'badge': '#f2c230'},
                 {'skin': SK[0], 'hair': '#f2b632', 'style': 'spiky', 'freckles': True, 'eye': '#2a6fb0'}),
    'knuckles': ('kid', {'T': '#3d8c4a', 'L': '#4a4a52', 'shoe': '#1d1d22', 'tie': '#1d1d22'},
                 {'skin': SK[1], 'hair': '#2a2422', 'style': 'short', 'mood': 'smirk', 'brow': '#1a1412'}),
    'tattle':   ('kid', {'T': '#4b7be0', 'L': '#3a3a48', 'shoe': '#1d1d22', 'tie': '#e8473c'},
                 {'skin': SK[4], 'hair': '#b5652e', 'style': 'short', 'glasses': '#2b2233', 'mood': 'smirk'}),
    'dot':      ('kid', {'T': '#f39c33', 'L': '#4a3a6a', 'shoe': '#7a2a3a', 'sock': '#ffffff'},
                 {'skin': SK[0], 'hair': '#f4d35e', 'style': 'pony', 'bow': '#4b7be0'}),
    'wilf':     ('kid', {'T': '#26b0b8', 'L': '#384050', 'shoe': '#2a2018'},
                 {'skin': SK[2], 'hair': '#5a3420', 'style': 'curly'}),
    'mo':       ('kid', {'T': '#e8d23a', 'L': '#304868', 'shoe': '#20202a'},
                 {'skin': SK[3], 'hair': '#18120f', 'style': 'short'}),
    'ada':      ('kid', {'T': '#b84fc0', 'L': '#3a3050', 'shoe': '#20202a', 'sock': '#f0f0f0'},
                 {'skin': SK[1], 'hair': '#8e2a1a', 'style': 'bob'}),
    'reg':      ('kid', {'T': '#7d8ff0', 'L': '#4a4048', 'shoe': '#2a2018'},
                 {'skin': SK[4], 'hair': '#d7b56d', 'style': 'short', 'freckles': True}),
    'nell':     ('kid', {'T': '#f06b8a', 'L': '#36304a', 'shoe': '#20202a', 'sock': '#ffffff'},
                 {'skin': SK[5], 'hair': '#2a1a10', 'style': 'long'}),
    'bas':      ('kid', {'T': '#46b04a', 'L': '#40404a', 'shoe': '#20202a'},
                 {'skin': SK[2], 'hair': '#e8e2d8', 'style': 'spiky'}),
    'ivy':      ('kid', {'T': '#9aa3b0', 'L': '#3a3f5a', 'shoe': '#5a2a2a', 'sock': '#f0f0f0'},
                 {'skin': SK[0], 'hair': '#7a3a1a', 'style': 'pony', 'bow': '#f2c230'}),
    'ogle':     ('man', {'T': '#8a5a34', 'L': '#4a3a2c', 'shoe': '#2a1a10', 'tie': '#b0303a', 'style': 'jacket'},
                 {'skin': SK[0], 'hair': '#b9b9b9', 'style': 'bald', 'mustache': '#9a9a9a', 'mood': 'stern', 'brow': '#8a8a8a'}),
    'vane':     ('woman', {'T': '#c43fa0', 'D': '#c43fa0', 'L': SK[4], 'shoe': '#2a1a2a', 'style': 'labcoat'},
                 {'skin': SK[4], 'hair': '#e05a1e', 'style': 'pony', 'bow': '#c43fa0', 'glasses': '#2b2233'}),
    'brandish': ('woman', {'T': '#3561c8', 'D': '#3561c8', 'L': SK[1], 'shoe': '#1d1d2a', 'style': 'dress', 'cardigan': '#7aa0e8'},
                 {'skin': SK[1], 'hair': '#d8d8dc', 'style': 'bun', 'mood': 'stern'}),
    'thistle':  ('head', {'T': '#3e2a52', 'L': '#2a2433', 'shoe': '#121016', 'tie': '#e0b030', 'style': 'suit', 'gown': '#1f1b28', 'trim': '#8a3fb0'},
                 {'skin': SK[0], 'hair': '#eeeeee', 'style': 'bald', 'beard': '#f0f0f0', 'mustache': '#f0f0f0', 'mortarboard': True, 'mood': 'stern', 'brow': '#bbbbbb'}),
}

DIMS = {
    'kid':   dict(thigh=24, thighW=13, shin=30, shinW=12, torsoW=30, torsoH=36, arm=30, armW=10, scale=0.96),
    'man':   dict(thigh=32, thighW=15, shin=40, shinW=13, torsoW=36, torsoH=52, arm=42, armW=12, scale=1.03),
    'woman': dict(thigh=32, thighW=14, shin=40, shinW=11, torsoW=34, torsoH=48, arm=40, armW=11, scale=1.03),
}
DIMS['head'] = DIMS['man']

rig = {}
for cid, (tpl, pal, head) in CAST.items():
    dm = DIMS[tpl]
    skin = head['skin']
    pal = dict(pal)
    pal['S'] = skin
    parts = {}

    def emit(name, res):
        w, h, piv, defs, body = res
        write_svg(os.path.join(CH, f'{cid}_{name}.svg'), w, h, body, 2.0, defs)
        parts[name] = [round(piv[0], 2), round(piv[1], 2)]

    trousers = pal['L']
    sock = pal.get('sock')
    if tpl == 'woman':
        emit('thigh', part_thigh(dm['thigh'], dm['thighW'], skin))
        emit('shin', part_shin(dm['shin'], dm['shinW'], skin, pal['shoe']))
    elif sock:  # kids in skirts/shorts + socks
        emit('thigh', part_thigh(dm['thigh'], dm['thighW'], skin))
        emit('shin', part_shin(dm['shin'], dm['shinW'], skin, pal['shoe'], sock=sock))
    else:
        emit('thigh', part_thigh(dm['thigh'], dm['thighW'], trousers))
        emit('shin', part_shin(dm['shin'], dm['shinW'], trousers, pal['shoe']))
    style = pal.get('style', 'jumper')
    skirt = 0
    if tpl == 'woman':
        skirt = 46 if style == 'dress' else 50
    elif sock:
        skirt = 16
        pal['D'] = shade(pal['T'], 0.6)
        style_k = 'dress'
    tstyle = style if tpl != 'kid' else ('dress' if sock else 'jumper')
    if tpl == 'kid' and sock:
        # pinafore-style: jumper on top, skirt below
        w, h, piv, defs, body = part_torso('dress', dm['torsoW'], dm['torsoH'], pal, skirt)
        # add collar & badge like the jumper
        cx = piv[0]
        body += (f'<path d="M{cx - 6},4 L{cx},13 L{cx + 6},4 Z" fill="#ffffff" {OL}/>')
        write_svg(os.path.join(CH, f'{cid}_torso.svg'), w, h, body, 2.0, defs)
        parts['torso'] = [round(piv[0], 2), round(piv[1], 2)]
    else:
        emit('torso', part_torso(tstyle, dm['torsoW'], dm['torsoH'], pal, skirt))
    sleeve = '#f4f6f8' if style == 'labcoat' else (pal.get('cardigan') or pal['T'])
    cuff = None if tpl == 'kid' else '#fbf7ee'
    emit('arm', part_arm(dm['arm'], dm['armW'], sleeve, skin, cuff))
    emit('head', part_head(head))
    if tpl == 'head':
        emit('gown', part_gown(dm['torsoW'] + 22, dm['torsoH'] + dm['thigh'] + 26, pal['gown'], pal['trim']))
    rig[cid] = dict(tpl=tpl, parts=parts, thigh=dm['thigh'], shin=dm['shin'], torsoH=dm['torsoH'],
                    arm=dm['arm'], scale=dm['scale'], legsBehind=True, skirt=skirt)

with open(os.path.join(ART, 'rig.json'), 'w') as f:
    json.dump(rig, f, indent=1)

# ---------------------------------------------------------------- props
def prop(name, w, h, body, defs='', scale=2.0, mip=True):
    write_svg(os.path.join(ART, name + '.svg'), w, h, body, scale, defs, mip)


# crest: the school's own emblem (inkwell + quill) on a quartered shield
def crest(on):
    shield = 'M4,4 L56,4 L56,30 Q56,56 30,66 Q4,56 4,30 Z'
    if on:
        g1, d1 = lin('#fff3a0', '#e0a020', 0, 0, 0, 1)
        g2, d2 = lin('#ff6b5a', '#b0242c', 0, 0, 0, 1)
        gl, d3 = rad([(0, '#fff6b0', .9), (.55, '#ffd84a', .35), (1, '#ffd84a', 0)])
        defs = d1 + d2 + d3
        a, bcol, edge, ink, quill = f'url(#{g1})', f'url(#{g2})', '#fffbe6', '#2b2233', '#ffffff'
        glow = f'<ellipse cx="30" cy="36" rx="30" ry="34" fill="url(#{gl})" transform="translate(0,0)"/>'
    else:
        g1, d1 = lin('#8a8478', '#5d584f', 0, 0, 0, 1)
        g2, d2 = lin('#6d6860', '#4a463f', 0, 0, 0, 1)
        defs = d1 + d2
        a, bcol, edge, ink, quill = f'url(#{g1})', f'url(#{g2})', '#a8a196', '#3a362f', '#bdb6aa'
        glow = ''
    body = (f'<g transform="translate(10,8)">{glow}'
            f'<path d="{shield}" fill="{a}" stroke="{INK}" stroke-width="2.4"/>'
            f'<path d="M30,4 L56,4 L56,30 L30,30 Z" fill="{bcol}"/><path d="M4,30 L30,30 L30,64 Q4,54 4,30 Z" fill="{bcol}"/>'
            f'<path d="{shield}" fill="none" stroke="{edge}" stroke-width="1.2" transform="translate(30,35) scale(.86) translate(-30,-35)"/>'
            f'<path d="M22,40 L38,40 L36,50 L24,50 Z" fill="{ink}"/><rect x="25" y="36" width="10" height="5" rx="1.5" fill="{ink}"/>'
            f'<path d="M31,38 Q36,22 46,14 Q42,26 33,38 Z" fill="{quill}" stroke="{INK}" stroke-width="1"/>'
            f'<path d="M4,30 L56,30 M30,4 L30,64" stroke="{INK}" stroke-width="1" opacity=".35"/>'
            f'</g>')
    return 80, 84, body, defs


for on in (False, True):
    w, h, b, d = crest(on)
    prop('crest_on' if on else 'crest_off', w, h, b, d)

# desk with an inkwell (front layer)
g1, d1 = lin('#c98a52', '#9a6234', 0, 0, 0, 1)
g2, d2 = lin('#b07444', '#7a4a26', 0, 0, 1, 0)
prop('desk', 64, 60,
     f'<path d="M4,16 L60,16 L56,24 L8,24 Z" fill="#e0a86a" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
     f'<rect x="6" y="22" width="52" height="14" rx="2" fill="url(#{g1})" stroke="{INK}" stroke-width="1.6"/>'
     f'<rect x="9" y="36" width="5" height="22" rx="1.5" fill="url(#{g2})" stroke="{INK}" stroke-width="1.4"/>'
     f'<rect x="50" y="36" width="5" height="22" rx="1.5" fill="url(#{g2})" stroke="{INK}" stroke-width="1.4"/>'
     f'<rect x="12" y="44" width="40" height="3" rx="1.5" fill="#7a4a26"/>'
     f'<ellipse cx="46" cy="18" rx="4" ry="1.6" fill="#1f2a5a" stroke="{INK}" stroke-width="1"/>'
     f'<rect x="16" y="12" width="16" height="5" rx="1" fill="#f6f2e6" stroke="{INK}" stroke-width="1" transform="rotate(-4 24 14)"/>'
     f'<line x1="18" y1="14" x2="29" y2="13" stroke="#8a9ab8" stroke-width=".8"/>',
     g1 and (d1 + d2))

# long dining table + bench
g1, d1 = lin('#d69a5e', '#a06a3a', 0, 0, 0, 1)
prop('table', 520, 70,
     f'<rect x="4" y="18" width="512" height="12" rx="3" fill="url(#{g1})" stroke="{INK}" stroke-width="2"/>'
     f'<rect x="20" y="30" width="10" height="36" rx="2" fill="#8a5a30" stroke="{INK}" stroke-width="1.6"/>'
     f'<rect x="490" y="30" width="10" height="36" rx="2" fill="#8a5a30" stroke="{INK}" stroke-width="1.6"/>'
     + ''.join(f'<ellipse cx="{x}" cy="16" rx="18" ry="5" fill="#ffffff" stroke="{INK}" stroke-width="1.4"/>'
               f'<ellipse cx="{x}" cy="14" rx="10" ry="3" fill="{c}"/>'
               for x, c in [(60, '#e8a33a'), (150, '#7cc45a'), (240, '#e8d06a'), (330, '#d8603a'), (420, '#e8a33a')])
     + f'<rect x="30" y="46" width="460" height="7" rx="3" fill="#b07a46" stroke="{INK}" stroke-width="1.6"/>',
     d1)

# head's desk
g1, d1 = lin('#7a3a20', '#4a2010', 0, 0, 0, 1)
prop('bigdesk', 190, 80,
     f'<rect x="4" y="16" width="182" height="12" rx="3" fill="#9a5230" stroke="{INK}" stroke-width="2"/>'
     f'<rect x="10" y="28" width="56" height="50" rx="3" fill="url(#{g1})" stroke="{INK}" stroke-width="2"/>'
     f'<rect x="124" y="28" width="56" height="50" rx="3" fill="url(#{g1})" stroke="{INK}" stroke-width="2"/>'
     f'<rect x="18" y="36" width="40" height="14" rx="2" fill="none" stroke="#c88a5a" stroke-width="1.4"/>'
     f'<rect x="18" y="56" width="40" height="14" rx="2" fill="none" stroke="#c88a5a" stroke-width="1.4"/>'
     f'<rect x="132" y="36" width="40" height="34" rx="2" fill="none" stroke="#c88a5a" stroke-width="1.4"/>'
     f'<rect x="96" y="4" width="34" height="12" rx="2" fill="#2a6a3a" stroke="{INK}" stroke-width="1.4"/>'
     f'<path d="M40,16 L44,2 L52,2 L50,16 Z" fill="#e8c860" stroke="{INK}" stroke-width="1.2"/>'
     f'<line x1="48" y1="2" x2="48" y2="-4" stroke="{INK}"/>', d1)

# bell rope (animated by swinging)
g1, d1 = lin('#e8c890', '#b08850', 0, 0, 1, 0)
rope = ''.join(f'<path d="M5,{y} q3,4 0,8" stroke="#8a6a40" stroke-width="1.2" fill="none"/>' for y in range(4, 222, 8))
prop('rope', 22, 270,
     f'<rect x="3" y="0" width="5" height="230" rx="2" fill="url(#{g1})" stroke="{INK}" stroke-width="1"/>{rope}'
     f'<path d="M1,224 L10,224 L14,262 Q5.5,270 -3,262 Z" fill="#c0283a" stroke="{INK}" stroke-width="1.6"/>'
     f'<rect x="0" y="222" width="11" height="6" rx="2" fill="#f2c230" stroke="{INK}" stroke-width="1.2"/>'
     + ''.join(f'<line x1="{x}" y1="232" x2="{x - 1}" y2="262" stroke="#7a1020" stroke-width=".8"/>' for x in (2, 5, 8, 11)),
     d1)

# pea pellet
g, d = rad([(0, '#c8ff8a', 1), (.7, '#4caf3a', 1), (1, '#2e7a22', 1)], .35, .35, .7)
prop('pea', 16, 16, f'<circle cx="8" cy="8" r="6.5" fill="url(#{g})" stroke="{INK}" stroke-width="1.2"/>', d)
# star (dizzy / sparkle)
pts = ' '.join(f'{12 + math.cos(a) * (11 if i % 2 == 0 else 4.5):.2f},{12 + math.sin(a) * (11 if i % 2 == 0 else 4.5):.2f}'
               for i, a in enumerate([-math.pi / 2 + k * math.pi / 5 for k in range(10)]))
prop('star', 24, 24, f'<polygon points="{pts}" fill="#ffd84a" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>')
# soft blob shadow
g, d = rad([(0, '#000000', .38), (1, '#000000', 0)])
prop('shadow', 100, 24, f'<ellipse cx="50" cy="12" rx="50" ry="12" fill="url(#{g})"/>', d, 1.0)
# sparkle particle
g, d = rad([(0, '#ffffff', 1), (.4, '#fff1a0', .9), (1, '#ffd84a', 0)])
prop('spark', 24, 24, f'<circle cx="12" cy="12" r="12" fill="url(#{g})"/>', d, 1.0)
# clouds
for i, blobs in enumerate([[(60, 52, 34), (100, 40, 40), (145, 55, 30), (30, 62, 22), (180, 64, 20)],
                           [(50, 50, 28), (90, 38, 34), (130, 52, 26)],
                           [(70, 46, 30), (115, 40, 26), (40, 58, 20), (150, 58, 18)]]):
    g, d = lin('#ffffff', '#dfe8f5', 0, 0, 0, 1)
    body = ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="url(#{g})"/>' for x, y, r in blobs)
    body += '<rect x="20" y="58" width="170" height="24" rx="12" fill="#e8eef8"/>'
    prop(f'cloud{i}', 210, 90, body, d, 1.5)
# sun
g, d = rad([(0, '#fffbe0', 1), (.45, '#ffe680', 1), (.5, '#ffd84a', .55), (1, '#ffd84a', 0)])
prop('sun', 200, 200, f'<circle cx="100" cy="100" r="100" fill="url(#{g})"/>', d, 1.0)
# bell icon for HUD
prop('bell_icon', 40, 40,
     f'<path d="M20,4 Q30,6 30,18 L31,27 L35,31 L5,31 L9,27 L10,18 Q10,6 20,4 Z" fill="#f2c230" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'
     f'<circle cx="20" cy="34" r="3.5" fill="#c08a10" stroke="{INK}" stroke-width="1.6"/><path d="M14,12 Q15,8 19,7" stroke="#fff6c0" stroke-width="2" fill="none" stroke-linecap="round"/>')

print('characters + props written')

# ================================================================= background
W, H = 6000, 1080
S = 3.75
FL = [dict(y=340, ceil=60), dict(y=620, ceil=340), dict(y=900, ceil=620)]
ROOMS = {
    'hall': (2, 750, 1500, '#e2cfa9'), 'dining': (2, 1500, 3000, '#f0b878'), 'gym': (2, 3000, 4312, '#9cc4d4'),
    'room1': (2, 4312, 5400, '#8eaad8'), 'eastg': (2, 5400, 5976, '#e2cfa9'),
    'westl': (1, 1100, 1650, '#e2cfa9'), 'map': (1, 1650, 3000, '#93c29b'), 'corr': (1, 3000, 3525, '#e2cfa9'),
    'library': (1, 3525, 4650, '#d8b77e'), 'art': (1, 4650, 5400, '#d29dc4'), 'eastl': (1, 5400, 5976, '#e2cfa9'),
    'history': (0, 2265, 3300, '#d89c7c'), 'top': (0, 3300, 3712, '#e2cfa9'), 'lab': (0, 3712, 4800, '#80c4bf'),
    'study': (0, 4800, 5976, '#a85466'),
}
BOARDS = ['room1', 'map', 'library', 'history', 'lab']
STAIRS = [(2, 1, 820, 1100), (1, 0, 3075, 3355), (2, 1, 5440, 5720)]
PARTS = {2: [1500, 3000, 4312, 5400], 1: [1650, 3000, 3525, 4650, 5400], 0: [3300, 3712, 4800]}
_gid[0] = 1000
defs = []
el = []


def R(x, y, w, h, fill, extra=''):
    el.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" fill="{fill}" {extra}/>')


def G(kind, *a, **k):
    gid, d = (lin if kind == 'lin' else rad)(*a, **k)
    defs.append(d)
    return f'url(#{gid})'


rng = random.Random(7)
# --- distant scenery behind the yard and low wing
el.append(f'<path d="M0,760 Q150,640 330,700 Q520,600 760,690 L760,920 L0,920 Z" fill="{G("lin", "#a9cfa0", "#86b98a")}"/>')
el.append(f'<path d="M0,820 Q220,730 440,800 Q600,740 760,790 L760,920 L0,920 Z" fill="{G("lin", "#8cc47e", "#6aa864")}"/>')
for x in range(10, 740, 46):
    r = rng.uniform(18, 30)
    el.append(f'<circle cx="{x}" cy="{805 - r * 0.6}" r="{r:.1f}" fill="#5f9f5c" opacity=".75"/>')
# town silhouette behind the low wing roof
for x in range(760, 2260, 70):
    hh = rng.uniform(40, 110)
    el.append(f'<rect x="{x}" y="{300 - hh:.0f}" width="{rng.uniform(40, 66):.0f}" height="{hh + 60:.0f}" fill="#b9cde6" opacity=".7"/>')
    el.append(f'<rect x="{x + 10}" y="{300 - hh - 18:.0f}" width="8" height="20" fill="#b9cde6" opacity=".7"/>')
# --- yard
R(0, 900, 760, 22, G('lin', '#7fc76a', '#58a34c'))
R(0, 918, 760, 162, G('lin', '#6b5a48', '#3f342a'))
el.append(f'<path d="M0,900 L760,900" stroke="#3e7a36" stroke-width="3"/>')
# fence
for x in range(12, 735, 26):
    el.append(f'<path d="M{x},902 L{x},826 L{x + 6},816 L{x + 12},826 L{x + 12},902 Z" fill="#fbf7ee" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>')
R(4, 842, 731, 9, '#fbf7ee', f'stroke="{INK}" stroke-width="1.6" rx="3"')
R(4, 876, 731, 9, '#fbf7ee', f'stroke="{INK}" stroke-width="1.6" rx="3"')
# tree
el.append(f'<path d="M200,900 Q206,760 196,700 L226,700 Q218,790 238,900 Z" fill="{G("lin", "#8a5a34", "#5a3a20", 0, 0, 1, 0)}" stroke="{INK}" stroke-width="2"/>')
for (x, y, r, c) in [(160, 640, 70, '#3f8f45'), (270, 630, 76, '#3f8f45'), (215, 560, 86, '#4caa52'), (130, 580, 52, '#4caa52'),
                     (300, 560, 60, '#5cbf5f'), (210, 500, 56, '#6ccf6a'), (250, 620, 50, '#4caa52')]:
    el.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}" stroke="{INK}" stroke-width="2"/>')
for (x, y) in [(180, 560), (250, 520), (300, 600), (140, 620), (230, 650)]:
    el.append(f'<circle cx="{x}" cy="{y}" r="7" fill="#e84a3a" stroke="{INK}" stroke-width="1.4"/>')
# bench
R(420, 862, 150, 10, '#c98a52', f'stroke="{INK}" stroke-width="1.6" rx="3"')
R(420, 836, 150, 10, '#c98a52', f'stroke="{INK}" stroke-width="1.6" rx="3"')
for x in (432, 552):
    R(x, 846, 8, 54, '#5a5f6a', f'stroke="{INK}" stroke-width="1.4"')
# hopscotch chalk marks on the tarmac strip (seen edge-on as dashes)
for x in range(560, 730, 30):
    R(x, 904, 18, 3, '#ffffff', 'opacity=".7" rx="1.5"')

# --- building shell
BR = '#b8644a'
# foundation band
R(735, 918, W - 735, 162, G('lin', '#8a8278', '#5d564e'))
for yy in range(930, 1080, 30):
    off = 0 if (yy // 30) % 2 else 40
    for xx in range(735 + off, W, 80):
        R(xx, yy, 78, 28, '#7a7268', f'rx="3" stroke="#5a534b" stroke-width="1.2"')
# low wing pitched roof
el.append(f'<path d="M712,342 L1488,196 L2265,342 Z" fill="{G("lin", "#6a7a96", "#46536c")}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>')
for i in range(1, 9):
    y = 342 - i * 17
    t = (342 - y) / 146
    xl, xr = 712 + (1488 - 712) * t, 2265 - (2265 - 1488) * t
    el.append(f'<path d="M{xl:.0f},{y} L{xr:.0f},{y}" stroke="#3a455c" stroke-width="2"/>')
el.append(f'<rect x="1080" y="214" width="56" height="96" fill="{BR}" stroke="{INK}" stroke-width="2.4"/>')
R(1070, 204, 76, 16, '#8a4a36', f'stroke="{INK}" stroke-width="2"')
# round school plaque in the gable
el.append(f'<circle cx="1488" cy="282" r="40" fill="#f6efe0" stroke="{INK}" stroke-width="3"/>')
el.append(f'<circle cx="1488" cy="282" r="32" fill="none" stroke="#b8644a" stroke-width="3"/>')
el.append('<path d="M1478,290 L1498,290 L1495,302 L1481,302 Z" fill="#2b2233"/><path d="M1489,290 Q1495,268 1508,258 Q1503,276 1492,290 Z" fill="#b8644a"/>')
# tall block roof slab + parapet
R(2240, 30, W - 2240, 32, G('lin', '#d8d2c8', '#aaa398'), f'stroke="{INK}" stroke-width="2"')
for x in range(2240, W, 48):
    R(x, 14, 28, 18, '#cfc8bd', f'stroke="{INK}" stroke-width="1.6" rx="2"')
# outer walls (brick) – left of low wing, left of tall block, right end
def brickwall(x, y, w, h):
    R(x, y, w, h, BR, f'stroke="{INK}" stroke-width="2"')
    for yy in range(int(y) + 12, int(y + h), 12):
        el.append(f'<path d="M{x},{yy} L{x + w},{yy}" stroke="#94503c" stroke-width="1.2"/>')


brickwall(735, 342, 24, 578)
brickwall(2240, 60, 26, 282)
brickwall(5976, 30, 24, 890)
# front door in the left wall (ground floor)
el.append(f'<path d="M735,900 L735,730 Q747,712 759,730 L759,900 Z" fill="#6a3a22" stroke="{INK}" stroke-width="2"/>')
el.append('<circle cx="753" cy="820" r="3" fill="#f2c230"/>')

# --- room interiors
for key, (f, x0, x1, col) in ROOMS.items():
    y, c = FL[f]['y'], FL[f]['ceil']
    top = c + 20
    if key == 'hall':
        top = 360  # double-height stair hall (ceiling at the low-wing roof)
    R(x0, top, x1 - x0, y - top, G('lin', shade(col, 1.08), shade(col, 0.9)))
    # subtle wallpaper stripes
    for xx in range(int(x0) + 10, int(x1), 36):
        R(xx, top, 14, y - top - 96, '#ffffff', 'opacity=".07"')
    # wainscot
    wc = shade(col, 0.62)
    R(x0, y - 96, x1 - x0, 96, G('lin', shade(wc, 1.1), shade(wc, 0.85)))
    for xx in range(int(x0) + 18, int(x1) - 60, 90):
        R(xx, y - 80, 70, 56, 'none', f'stroke="{shade(wc, 1.3)}" stroke-width="2" rx="4"')
    R(x0, y - 100, x1 - x0, 6, shade(col, 1.25), f'stroke="{shade(col, 0.7)}" stroke-width="1"')
    R(x0, y - 14, x1 - x0, 14, shade(wc, 0.7))
    # ceiling shadow under the slab above
    R(x0, top, x1 - x0, 26, G('lin', '#000000', '#000000', stops=[(0, '#000000', .28), (1, '#000000', 0)]))
# stair hall upper part (above mid-floor level at x 750..1100) shares the hall colours: handled by top=360

# --- windows
WINS = [(2, 1300), (2, 1700), (2, 2300), (2, 3330), (2, 3600), (2, 3950), (2, 5000), (2, 5250),
        (1, 1330), (1, 2700), (1, 5250), (1, 5880), (0, 2900), (0, 3500), (0, 4620), (0, 5500), (2, 900)]
for f, x in WINS:
    y, c = FL[f]['y'], FL[f]['ceil']
    top = c + 52 if not (f == 2 and x == 900) else 420
    hgt = 128 if not (f == 2 and x == 900) else 200
    w = 92
    sky = G('lin', '#bfe3ff', '#eaf6ff')
    el.append(f'<path d="M{x - w / 2},{top + hgt} L{x - w / 2},{top + 40} Q{x - w / 2},{top} {x},{top} Q{x + w / 2},{top} {x + w / 2},{top + 40} L{x + w / 2},{top + hgt} Z" '
              f'fill="{sky}" stroke="#fbf7ee" stroke-width="9"/>')
    el.append(f'<path d="M{x - w / 2 - 5},{top + hgt} L{x - w / 2 - 5},{top + 40} Q{x - w / 2 - 5},{top - 5} {x},{top - 5} Q{x + w / 2 + 5},{top - 5} {x + w / 2 + 5},{top + 40} L{x + w / 2 + 5},{top + hgt}" fill="none" stroke="{INK}" stroke-width="2"/>')
    el.append(f'<path d="M{x},{top + 2} L{x},{top + hgt} M{x - w / 2},{top + hgt * 0.55} L{x + w / 2},{top + hgt * 0.55}" stroke="#fbf7ee" stroke-width="6"/>')
    el.append(f'<path d="M{x - w / 2 + 10},{top + hgt - 14} L{x - w / 2 + 30},{top + 40}" stroke="#ffffff" stroke-width="6" opacity=".55" stroke-linecap="round"/>')
    R(x - w / 2 - 12, top + hgt, w + 24, 10, '#fbf7ee', f'stroke="{INK}" stroke-width="2" rx="3"')
    if f == 0 and x == 5500:  # curtains in the study
        for s in (-1, 1):
            cx0 = x + s * (w / 2 + 6)
            el.append(f'<path d="M{cx0 - 22},{top - 14} L{cx0 + 22},{top - 14} Q{cx0 + 10},{top + hgt * 0.6} {cx0 + 18},{top + hgt + 14} L{cx0 - 18},{top + hgt + 14} Q{cx0 - 10},{top + hgt * 0.6} {cx0 - 22},{top - 14} Z" fill="#6a1a2e" stroke="{INK}" stroke-width="2"/>')

# --- pendant lamps with warm glow
for key, (f, x0, x1, col) in ROOMS.items():
    if key in ('gym',):
        continue
    y, c = FL[f]['y'], FL[f]['ceil']
    n = max(1, int((x1 - x0) // 420))
    for i in range(n):
        lx = x0 + (x1 - x0) * (i + 0.5) / n
        if key == 'study':
            lx = 5180
        if any(abs(lx - wx) < 80 and wf == f for wf, wx in WINS):
            lx += 110
        el.append(f'<ellipse cx="{lx}" cy="{c + 100}" rx="150" ry="120" fill="{G("rad", [(0, "#fff2c0", .45), (1, "#fff2c0", 0)])}"/>')
        el.append(f'<path d="M{lx},{c + 20} L{lx},{c + 62}" stroke="{INK}" stroke-width="2"/>')
        el.append(f'<path d="M{lx - 26},{c + 82} Q{lx - 24},{c + 60} {lx},{c + 60} Q{lx + 24},{c + 60} {lx + 26},{c + 82} Z" fill="#2f6e5a" stroke="{INK}" stroke-width="2"/>')
        el.append(f'<ellipse cx="{lx}" cy="{c + 84}" rx="9" ry="5" fill="#fff6c8"/>')

# --- blackboards
for key in BOARDS:
    f, x0, x1, col = ROOMS[key]
    y = FL[f]['y']
    bx, by, bw, bh = x0 + 45, y - 228, 290, 136
    R(bx - 10, by - 10, bw + 20, bh + 20, G('lin', '#b07444', '#7a4a26'), f'stroke="{INK}" stroke-width="2.4" rx="6"')
    R(bx, by, bw, bh, G('lin', '#2f5a48', '#1d3d31'), f'stroke="{INK}" stroke-width="1.6" rx="3"')
    el.append(f'<path d="M{bx + 20},{by + 110} Q{bx + 90},{by + 96} {bx + 150},{by + 116}" stroke="#ffffff" stroke-width="10" opacity=".06" fill="none" stroke-linecap="round"/>')
    R(bx - 4, by + bh + 6, bw + 8, 8, '#8a5a30', f'stroke="{INK}" stroke-width="1.4" rx="2"')
    R(bx + 200, by + bh + 1, 22, 6, '#ffffff', 'rx="2"')
    R(bx + 232, by + bh + 1, 30, 7, '#c9a46b', f'rx="2" stroke="{INK}" stroke-width="1"')

# --- room furniture & decoration (behind characters)
def bookshelf(x, y, w, h, rows):
    R(x, y, w, h, '#7a4a26', f'stroke="{INK}" stroke-width="2.4" rx="4"')
    rh = (h - 12) / rows
    cols = ['#d94a3a', '#3a72c8', '#3aa86a', '#e8b23a', '#9a4ac0', '#f0e6d0', '#2a8a9a', '#c86a3a']
    for r in range(rows):
        yy = y + 6 + r * rh
        R(x + 6, yy, w - 12, rh - 4, '#5a3418')
        xx = x + 8
        while xx < x + w - 14:
            bw = rng.uniform(7, 13)
            bh = rh - 6 - rng.uniform(0, 12)
            if rng.random() < 0.08:
                el.append(f'<rect x="{xx:.1f}" y="{yy + rh - 4 - bh * 0.6:.1f}" width="{bh * 0.9:.1f}" height="{bw:.1f}" fill="{rng.choice(cols)}" stroke="{INK}" stroke-width="1" rx="1.5" transform="rotate(-12 {xx:.1f} {yy + rh - 4:.1f})"/>')
                xx += bh * 0.6
                continue
            R(xx, yy + rh - 4 - bh, bw, bh, rng.choice(cols), f'stroke="{INK}" stroke-width="1" rx="1.5"')
            xx += bw + 0.5
        R(x + 6, yy + rh - 4, w - 12, 4, '#9a6234')


# hall: notice board + coat pegs + trophy cabinet
y = 900
R(1150, y - 250, 180, 120, '#c69a6a', f'stroke="{INK}" stroke-width="2.4" rx="5"')
for i, (px, py, pc) in enumerate([(1165, 640, '#fff6a0'), (1210, 664, '#ffffff'), (1262, 648, '#a0d8ff'), (1180, 700, '#ffc0d0'), (1240, 712, '#c8ffb0'), (1290, 690, '#ffffff')]):
    el.append(f'<rect x="{px}" y="{py}" width="40" height="44" fill="{pc}" stroke="{INK}" stroke-width="1.2" transform="rotate({rng.uniform(-6, 6):.1f} {px + 20} {py + 22})"/>')
    el.append(f'<circle cx="{px + 20}" cy="{py + 4}" r="3.5" fill="#e84a3a" stroke="{INK}" stroke-width="1"/>')
for i, x in enumerate(range(1370, 1480, 36)):
    el.append(f'<circle cx="{x}" cy="{y - 176}" r="5" fill="#b0b0b8" stroke="{INK}" stroke-width="1.4"/>')
    cc = ['#e8473c', '#3a72c8', '#e8b23a'][i % 3]
    el.append(f'<path d="M{x - 18},{y - 168} Q{x},{y - 182} {x + 18},{y - 168} L{x + 14},{y - 100} L{x - 14},{y - 100} Z" fill="{cc}" stroke="{INK}" stroke-width="1.6"/>')
# dining hall: serving hatch + menu board + posters
y = 900
R(1700, y - 260, 280, 120, '#fbf7ee', f'stroke="{INK}" stroke-width="2.4" rx="6"')
R(1716, y - 246, 248, 92, '#5a3a2a', 'rx="4"')
for i, x in enumerate(range(1730, 1960, 46)):
    el.append(f'<ellipse cx="{x + 16}" cy="{y - 162}" rx="22" ry="7" fill="#d8d8e0" stroke="{INK}" stroke-width="1.4"/>')
    el.append(f'<path d="M{x},{y - 166} Q{x + 16},{y - 196} {x + 32},{y - 166} Z" fill="{["#e8a33a", "#7cc45a", "#d8603a", "#e8d06a", "#c87a3a"][i % 5]}" stroke="{INK}" stroke-width="1.2"/>')
R(2480, y - 270, 130, 160, '#2f4a3a', f'stroke="#8a5a30" stroke-width="10" rx="6"')
for i in range(5):
    R(2500, y - 244 + i * 26, 60 + rng.uniform(0, 30), 6, '#f0f0e0', 'opacity=".8" rx="3"')
el.append(f'<circle cx="2720" cy="{y - 200}" r="46" fill="#fbf7ee" stroke="{INK}" stroke-width="3"/>')
el.append(f'<path d="M2720,{y - 200} L2720,{y - 232} M2720,{y - 200} L2744,{y - 192}" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>')
# gym: wall bars, rope, hoop, mats
y = 900
for x in range(3080, 3260, 22):
    R(x, y - 300, 8, 300, '#d8a868', f'stroke="{INK}" stroke-width="1.2" rx="3"')
for yy in range(y - 280, y, 30):
    R(3080, yy, 188, 6, '#c08a50', 'rx="3"')
el.append(f'<path d="M4050,640 Q4056,760 4046,860" stroke="#c8a870" stroke-width="9" fill="none" stroke-linecap="round"/>')
el.append(f'<path d="M4050,640 Q4056,760 4046,860" stroke="{INK}" stroke-width="1.4" fill="none" stroke-dasharray="4 6"/>')
R(4150, 680, 110, 76, '#ffffff', f'stroke="{INK}" stroke-width="2.4" rx="4"')
R(4180, 712, 50, 36, 'none', 'stroke="#e8473c" stroke-width="3"')
el.append(f'<ellipse cx="4205" cy="760" rx="34" ry="7" fill="none" stroke="#f07a1a" stroke-width="5"/>')
for i in range(5):
    el.append(f'<path d="M{4174 + i * 15},{764} L{4182 + i * 10},{800}" stroke="#ffffff" stroke-width="2"/>')
for i, c in enumerate(['#3a72c8', '#e8473c', '#3aa86a']):
    R(3480 + i * 10, y - 40 - i * 22, 200, 22, c, f'stroke="{INK}" stroke-width="1.6" rx="8"')
# map room: wall map + globe
y = 620
R(2470, y - 250, 330, 170, '#7ab8e8', f'stroke="#8a5a30" stroke-width="10" rx="4"')
for (pts, c) in [('2500,410 2560,392 2600,420 2580,470 2530,462', '#7cc45a'), ('2620,400 2700,390 2740,430 2700,450 2650,440', '#e8c860'),
                 ('2680,470 2740,460 2770,500 2720,520', '#e88a6a'), ('2520,490 2570,488 2590,520 2540,530', '#c8a0e8')]:
    el.append(f'<polygon points="{pts}" fill="{c}" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>')
el.append(f'<path d="M2480,450 L2790,450" stroke="#ffffff" stroke-width="1.4" stroke-dasharray="6 6"/>')
el.append(f'<circle cx="2140" cy="{y - 190}" r="40" fill="{G("rad", [(0, "#a0d8ff", 1), (1, "#3a72c8", 1)], .35, .35, .8)}" stroke="{INK}" stroke-width="2.4"/>')
el.append(f'<path d="M2116,{y - 210} Q2140,{y - 222} 2156,{y - 200} Q2140,{y - 186} 2120,{y - 194} Z" fill="#7cc45a"/>')
el.append(f'<path d="M2140,{y - 150} L2140,{y - 120} M2116,{y - 116} L2164,{y - 116}" stroke="#8a5a30" stroke-width="6" stroke-linecap="round"/>')
# library shelves
y = 620
for x in (3920, 4180, 4440):
    bookshelf(x, y - 290, 190, 150, 3)
# art room
y = 620
for (x, c1, c2) in [(4700, '#e8473c', '#f2c230'), (4840, '#3a72c8', '#7cc45a')]:
    R(x, y - 250, 110, 84, '#ffffff', f'stroke="#c8a060" stroke-width="7"')
    el.append(f'<circle cx="{x + 40}" cy="{y - 212}" r="22" fill="{c1}" opacity=".85"/>')
    el.append(f'<rect x="{x + 54}" y="{y - 226}" width="42" height="40" fill="{c2}" opacity=".85" transform="rotate(12 {x + 74} {y - 206})"/>')
for x in (5080, 5300):
    el.append(f'<path d="M{x - 30},{y} L{x},{y - 200} L{x + 30},{y}" stroke="#a87444" stroke-width="7" fill="none" stroke-linecap="round"/>')
    R(x - 46, y - 190, 92, 74, '#fbf7ee', f'stroke="{INK}" stroke-width="2"')
    el.append(f'<path d="M{x - 36},{y - 130} Q{x - 10},{y - 176} {x + 10},{y - 150} Q{x + 26},{y - 126} {x + 38},{y - 160}" stroke="{rng.choice(["#e8473c", "#3a72c8", "#3aa86a"])}" stroke-width="7" fill="none" stroke-linecap="round"/>')
    R(x - 54, y - 116, 108, 7, '#a87444', f'stroke="{INK}" stroke-width="1.4" rx="3"')
for i, c in enumerate(['#e8473c', '#f2c230', '#3a72c8', '#3aa86a', '#b84fc0']):
    R(4960 + i * 26, y - 128, 20, 26, c, f'stroke="{INK}" stroke-width="1.4" rx="3"')
# history room: tapestry + timeline + suit-of-armour silhouette
y = 340
R(2700, y - 270, 240, 26, '#f0dcae', f'stroke="{INK}" stroke-width="2" rx="4"')
for i in range(7):
    el.append(f'<circle cx="{2720 + i * 33}" cy="{y - 257}" r="5" fill="#8a3a1a"/>')
el.append(f'<path d="M3020,{y - 280} L3150,{y - 280} L3150,{y - 120} L3085,{y - 140} L3020,{y - 120} Z" fill="#8a2a3a" stroke="{INK}" stroke-width="2.4"/>')
el.append(f'<path d="M3060,{y - 240} L3110,{y - 240} L3110,{y - 200} Q3085,{y - 176} 3060,{y - 200} Z" fill="#f2c230" stroke="{INK}" stroke-width="1.6"/>')
# lab shelves with flasks + periodic chart + sink
y = 340
R(4080, y - 252, 520, 8, '#7a4a26', f'stroke="{INK}" stroke-width="1.4" rx="3"')
R(4080, y - 190, 520, 8, '#7a4a26', f'stroke="{INK}" stroke-width="1.4" rx="3"')
for row, yy in enumerate((y - 252, y - 190)):
    for i, x in enumerate(range(4096, 4590, 40)):
        lc = ['#5ad86a', '#e85ad8', '#f2d23a', '#5ab8f2', '#f2783a'][(i + row) % 5]
        if (i + row) % 2:
            el.append(f'<path d="M{x},{yy} L{x + 6},{yy - 26} L{x + 6},{yy - 40} L{x + 14},{yy - 40} L{x + 14},{yy - 26} L{x + 20},{yy} Z" fill="#e0f4ff" fill-opacity=".7" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>')
            el.append(f'<path d="M{x + 2},{yy - 1} L{x + 5},{yy - 12} L{x + 15},{yy - 12} L{x + 18},{yy - 1} Z" fill="{lc}"/>')
        else:
            R(x + 3, yy - 36, 14, 36, '#e0f4ff', f'stroke="{INK}" stroke-width="1.4" rx="5" fill-opacity=".7"')
            R(x + 4, yy - 18, 12, 17, lc, 'rx="4"')
R(4640, y - 260, 120, 90, '#fbf7ee', f'stroke="{INK}" stroke-width="2" rx="3"')
for r in range(5):
    for cc in range(8):
        if r == 0 and 0 < cc < 7:
            continue
        R(4648 + cc * 13.5, y - 252 + r * 16, 11, 13, ['#f2a0a0', '#a0c8f2', '#a0f2b8', '#f2e0a0'][(r + cc) % 4], 'rx="1.5"')
# study: rug edge, bookcase, owl portrait, cabinet, clock
y = 340
R(4830, y - 6, 1120, 6, '#8a1a2e')
bookshelf(4840, y - 270, 150, 260, 5)
R(5300, y - 270, 120, 140, '#d9a630', f'stroke="{INK}" stroke-width="3" rx="4"')
R(5312, y - 258, 96, 116, G('lin', '#4a6a9a', '#2a3a5a'), 'rx="2"')
el.append(f'<ellipse cx="5360" cy="{y - 190}" rx="28" ry="34" fill="#a8784a" stroke="{INK}" stroke-width="2"/>')
for ex in (5348, 5372):
    el.append(f'<circle cx="{ex}" cy="{y - 202}" r="10" fill="#fbf7ee" stroke="{INK}" stroke-width="1.6"/><circle cx="{ex + 1}" cy="{y - 201}" r="4.5" fill="{INK}"/>')
el.append(f'<path d="M5355,{y - 192} L5365,{y - 192} L5360,{y - 184} Z" fill="#f2c230" stroke="{INK}" stroke-width="1"/>')
el.append(f'<path d="M5336,{y - 222} L5342,{y - 236} L5350,{y - 224} M5370,{y - 224} L5378,{y - 236} L5384,{y - 222}" fill="#a8784a" stroke="{INK}" stroke-width="1.6"/>')
R(5700, y - 170, 80, 170, '#4a4e58', f'stroke="{INK}" stroke-width="2.4" rx="4"')
for i in range(3):
    R(5708, y - 160 + i * 54, 64, 46, '#5e6370', f'stroke="{INK}" stroke-width="1.4" rx="3"')
    R(5728, y - 140 + i * 54, 24, 6, '#c8ccd4', 'rx="3"')
R(5620, y - 260, 50, 260, '#6a3a1e', f'stroke="{INK}" stroke-width="2.4" rx="6"')
el.append(f'<circle cx="5645" cy="{y - 220}" r="18" fill="#fbf7ee" stroke="{INK}" stroke-width="2"/>')
el.append(f'<path d="M5645,{y - 220} L5645,{y - 232} M5645,{y - 220} L5653,{y - 216}" stroke="{INK}" stroke-width="2.4" stroke-linecap="round"/>')
R(5633, y - 170, 24, 90, '#3a1e0e', 'rx="4"')
el.append(f'<circle cx="5645" cy="{y - 100}" r="9" fill="#f2c230" stroke="{INK}" stroke-width="1.4"/>')
# corridors / landings: lockers, plants, radiators
def lockers(x, y, n):
    for i in range(n):
        c = ['#3a72c8', '#e8473c', '#3aa86a', '#f2b632'][i % 4]
        R(x + i * 40, y - 196, 38, 196, c, f'stroke="{INK}" stroke-width="2" rx="3"')
        for k in range(4):
            R(x + i * 40 + 8, y - 186 + k * 6, 22, 2.5, shade(c, 0.6), 'rx="1"')
        R(x + i * 40 + 28, y - 110, 4, 16, '#e0e0e8', 'rx="2"')


def plant(x, y):
    el.append(f'<path d="M{x - 22},{y - 50} L{x + 22},{y - 50} L{x + 16},{y} L{x - 16},{y} Z" fill="#c86a3a" stroke="{INK}" stroke-width="2"/>')
    for a in (-60, -30, 0, 30, 60, -45, 45):
        el.append(f'<path d="M{x},{y - 50} Q{x + a * 0.6},{y - 120} {x + a * 1.1},{y - 140}" stroke="#3a8a3a" stroke-width="9" fill="none" stroke-linecap="round"/>')


def radiator(x, y):
    for i in range(8):
        R(x + i * 12, y - 80, 10, 60, '#e8e8ee', f'stroke="{INK}" stroke-width="1.2" rx="4"')
    R(x - 2, y - 22, 100, 4, '#c8c8d0')


lockers(3120, 620, 4)
plant(3460, 620)
radiator(5470, 900)
plant(5900, 900)
lockers(5560, 620, 0)
plant(1580, 620)
radiator(1180, 620)
plant(3600, 340)
radiator(5800, 620)
# --- stairs (wooden, 14 steps of 20px)
for (lo, hi, xl, xh) in STAIRS:
    ylo = FL[lo]['y']
    el.append(f'<path d="M{xl - 20},{ylo} L{xh},{ylo - 280} L{xh + 20},{ylo - 280} L{xh + 20},{ylo - 260} L{xl + 10},{ylo} Z" fill="#6a4426" stroke="{INK}" stroke-width="2"/>')
    el.append(f'<path d="M{xl},{ylo} L{xh},{ylo - 280} L{xh},{ylo} Z" fill="#000000" opacity=".12"/>')
    for i in range(14):
        x, yy = xl + i * 20, ylo - i * 20
        R(x - 8, yy - 20, 28, 6, '#c8925a', f'stroke="{INK}" stroke-width="1.4" rx="2"')
        R(x - 8, yy - 14, 6, 14, '#9a6a3a')
    # banister
    for i in range(0, 15):
        x, yy = xl + i * 20, ylo - i * 20
        R(x - 2, yy - 96, 4, 78, '#f0d8a8', f'stroke="{INK}" stroke-width=".8"')
    el.append(f'<path d="M{xl - 8},{ylo - 100} L{xh + 4},{ylo - 384}" stroke="{INK}" stroke-width="12" stroke-linecap="round"/>')
    el.append(f'<path d="M{xl - 8},{ylo - 100} L{xh + 4},{ylo - 384}" stroke="#a8683a" stroke-width="8" stroke-linecap="round"/>')
    for (px, py) in ((xl - 14, ylo), (xh + 2, ylo - 280)):
        R(px - 7, py - 112, 14, 112, '#8a5430', f'stroke="{INK}" stroke-width="2" rx="3"')
        el.append(f'<circle cx="{px}" cy="{py - 116}" r="9" fill="#a8683a" stroke="{INK}" stroke-width="2"/>')

# --- floor slabs (drawn last so they sit on top of wall edges)
def slab(x0, x1, y):
    R(x0, y, x1 - x0, 6, G('lin', '#d9a46a', '#b07a46'))
    R(x0, y + 6, x1 - x0, 14, G('lin', '#efe9df', '#cfc7ba'))
    el.append(f'<path d="M{x0},{y} L{x1},{y} M{x0},{y + 20} L{x1},{y + 20}" stroke="{INK}" stroke-width="2"/>')


slab(759, W, 900)
slab(1100, W - 24, 620)
slab(2266, W - 24, 340)
slab(759, 2240, 340)
# --- partitions (lintel blocks over open doorways)
for f, xs in PARTS.items():
    y, c = FL[f]['y'], FL[f]['ceil']
    for x in xs:
        el.append(f'<path d="M{x - 14},{c + 20} L{x + 14},{c + 20} L{x + 14},{y - 200} Q{x},{y - 186} {x - 14},{y - 200} Z" fill="{G("lin", "#efe6d6", "#cfc4b2", 0, 0, 1, 0)}" stroke="{INK}" stroke-width="2"/>')
        R(x - 24, y - 212, 48, 12, '#a8683a', f'stroke="{INK}" stroke-width="1.6" rx="3"')

body = ''.join(el)
dstr = ''.join(defs)
TILE = 1500
for i in range(W // TILE):
    x0 = i * TILE
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{TILE}" height="{H}" viewBox="{x0} 0 {TILE} {H}">'
           f'<defs>{dstr}</defs>{body}</svg>')
    p = os.path.join(ART, f'bg{i}.svg')
    with open(p, 'w') as f:
        f.write(svg)
    with open(p + '.import', 'w') as f:
        f.write(IMPORT.format(mip='false'))
print('background tiles written', len(body) // 1024, 'KB of SVG')
