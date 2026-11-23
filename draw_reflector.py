#!/usr/bin/env python3
"""Parametric SVG reflector for trumpet, trombone, and euphonium.

IMPORTANT: contact_offset is a provisional geometric assumption, NOT a
measured value. Verify fit and all dimensions before cutting.
"""
import argparse
import cmath
import math
from pathlib import Path
from xml.sax.saxutils import escape

PRESETS = {
    'trumpet': dict(bells=[123, 127, 136, 140], outer=180, inner=92),
    'trombone': dict(bells=[203.2, 215.9, 228.6, 254], outer=300, inner=150),
    'euphonium': dict(bells=[266.7, 279.4, 292.1, 304.8], outer=360, inner=190),
}

def petal_profile(u):
    """Petal height (0..1) at position u in [-1, 1] across one petal; 0 = tip."""
    return math.cos(math.pi * u / 2) ** 0.6 * (1 - 0.25 * abs(u))

def sunflower_points(outer, petals, petal_length, samples_per_petal=64):
    """Outline points for a sunflower edge. Valleys touch the outer circle and
    petal tips reach outer/2 + petal_length. The first tip is at the top."""
    pts = []
    total = petals * samples_per_petal
    for k in range(total):
        phase = k / samples_per_petal          # petals from the top, 0 = tip
        u = ((phase + 0.5) % 1) * 2 - 1
        r = outer / 2 + petal_length * petal_profile(u)
        a = math.radians(-90 + 360 * k / total)
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts

GASKET_MARGIN = 2  # mm between the gasket's boundary circle and the outer edge

def apollonian_gasket(inner_r, outer_limit, min_r):
    """Apollonian gasket around a centre opening of radius inner_r.

    A Steiner chain of n equal circles fits between the opening and a boundary
    circle of radius Rg; n is the smallest count with Rg <= outer_limit. Every
    gap is then filled recursively (Descartes' theorem) down to radius min_r.
    Returns (n, Rg, [(x, y, r), ...]) with the first circle at the top
    (SVG coordinates, y down).
    """
    if outer_limit <= inner_r:
        raise ValueError('No room for the Apollonian pattern between --inner and --outer')
    n = 3
    while True:
        s = math.sin(math.pi / n)
        Rg = inner_r * (1 + s) / (1 - s)
        if Rg <= outer_limit:
            break
        n += 1
        if n > 500:
            raise ValueError('Apollonian pattern needs too many circles; increase --outer')
    rho, d = (Rg - inner_r) / 2, (Rg + inner_r) / 2
    outer_c, inner_c = (-1 / Rg, 0j), (1 / inner_r, 0j)
    chain = [(1 / rho, cmath.rect(d, math.radians(-90 + 360 * j / n))) for j in range(n)]

    def tangent_error(c, k, z):
        r = 1 / c[0]
        want = abs(1 / k + r) if k > 0 else abs(-1 / k - r)
        return abs(abs(c[1] - z) - want)

    def descartes(a, b, c):
        (k1, z1), (k2, z2), (k3, z3) = a, b, c
        k4 = k1 + k2 + k3 + 2 * math.sqrt(max(0, k1*k2 + k2*k3 + k3*k1))
        root = cmath.sqrt(k1*k2*z1*z2 + k2*k3*z2*z3 + k3*k1*z3*z1)
        cands = [(k4, (k1*z1 + k2*z2 + k3*z3 + sg * 2 * root) / k4) for sg in (1, -1)]
        return min(cands, key=lambda c4: sum(tangent_error(c4, k, z) for k, z in (a, b, c)))

    found = list(chain)
    stack = []
    for j in range(n):
        A, B = chain[j], chain[(j + 1) % n]
        stack += [(inner_c, A, B), (outer_c, A, B)]
    while stack:
        a, b, c = stack.pop()
        new = descartes(a, b, c)
        if 1 / new[0] < min_r:
            continue
        found.append(new)
        stack += [(a, b, new), (b, c, new), (a, c, new)]
    return n, Rg, [(z.real, z.imag, 1 / k) for k, z in found]

def svg(instrument, bells, outer, inner, offset, hole_diameter, thickness, output,
        shape='circle', petals=20, petal_length=None, pattern='none', pattern_min=2):
    """Create true-size SVG in millimeters, red cut paths and blue labels."""
    if not 0 < inner < outer or hole_diameter <= 0 or offset < 0:
        raise ValueError('Invalid dimensions')
    if shape not in ('circle', 'sunflower'):
        raise ValueError(f'Unknown shape: {shape}')
    if petal_length is None:
        petal_length = round(0.15 * outer, 1)
    if shape == 'sunflower' and (petals < 3 or petal_length <= 0):
        raise ValueError('Sunflower needs at least 3 petals and a positive petal length')
    if pattern not in ('none', 'apollonian'):
        raise ValueError(f'Unknown pattern: {pattern}')
    if pattern == 'apollonian' and pattern_min <= 0:
        raise ValueError('--pattern-min must be positive')
    if not bells or any(b <= 0 for b in bells):
        raise ValueError('Bell diameters must be positive')
    n = len(bells)
    # Interleave bell sizes around circumference: each bell gets 3 holes 120 deg apart.
    # The resulting 3*n angular slots are evenly spaced.
    holes = []
    for i, bell in enumerate(bells):
        radius = bell / 2 + offset
        for j in range(3):
            angle = -90 + i * 360 / (3*n) + j*120
            holes.append((radius, angle, bell))
    min_edge = min(outer/2-r-hole_diameter/2 for r, _, _ in holes)
    if min_edge < 0:
        raise ValueError(f'Holes extend beyond outside edge by {-min_edge:.2f} mm; increase --outer or reduce --offset')
    # Detect overlapping holes.
    xy = [(r*math.cos(math.radians(a)),r*math.sin(math.radians(a))) for r,a,_ in holes]
    for i in range(len(xy)):
        for j in range(i+1,len(xy)):
            if math.dist(xy[i],xy[j]) < hole_diameter+1:
                raise ValueError(f'Holes {i+1} and {j+1} too close; change bell sizes or layout')
    margin = 8
    overall = outer + (2*petal_length if shape == 'sunflower' else 0)
    size = overall+2*margin
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}mm" height="{size}mm" viewBox="{-size/2} {-size/2} {size} {size}">',
             f'<title>{escape(instrument.title())} bell reflector, provisional geometry</title>',
             '<g id="laser-cut" fill="none" stroke="#ff0000" stroke-width="0.1">',
             f'<circle r="{inner/2}"/>']
    if shape == 'sunflower':
        pts = sunflower_points(outer, petals, petal_length)
        parts.append('<path d="M' + ' L'.join(f'{x:.3f},{y:.3f}' for x, y in pts) + ' Z"/>')
    else:
        parts.append(f'<circle r="{outer/2}"/>')
    for x,y in xy:
        parts.append(f'<circle cx="{x:.4f}" cy="{y:.4f}" r="{hole_diameter/2:.4f}"/>')
    parts.append('</g><g id="engrave-labels" fill="#0055ff" font-family="Arial,sans-serif" font-size="3.7" text-anchor="middle" dominant-baseline="middle">')
    for (r,a,b), (x,y) in zip(holes,xy):
        # labels are INSIDE each hole, toward center; these indicate BELL diameter
        lr = r - 7
        lx = lr*math.cos(math.radians(a))
        ly = lr*math.sin(math.radians(a))
        parts.append(f'<text x="{lx:.3f}" y="{ly:.3f}">{b:g}</text>')
    parts.append('</g>')
    pattern_info = ''
    if pattern == 'apollonian':
        gn, Rg, circles = apollonian_gasket(inner/2, outer/2 - GASKET_MARGIN, pattern_min)
        parts.append('<g id="score-pattern" fill="none" stroke="#0055ff" stroke-width="0.1">')
        parts.append(f'<circle r="{Rg:.4f}"/>')
        for x, y, r in circles:
            parts.append(f'<circle cx="{x:.4f}" cy="{y:.4f}" r="{r:.4f}"/>')
        parts.append('</g>')
        pattern_info = f', Apollonian pattern {len(circles)} circles ({gn} in the main ring)'
    parts.append('</svg>')
    Path(output).write_text('\n'.join(parts), encoding='utf-8')
    shape_info = f', sunflower {petals} petals x {petal_length:g} mm (overall {overall:g} mm)' if shape == 'sunflower' else ''
    print(f'Wrote {output}: {len(holes)} holes, outer {outer:g} mm, inner {inner:g} mm{shape_info}{pattern_info}, min outer edge clearance {min_edge:.2f} mm')
    print('WARNING: Offset and ring dimensions are provisional; confirm geometry before fabrication.')

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--instrument', choices=PRESETS, default='euphonium')
    p.add_argument('--bells', type=float, nargs='+', help='Bell diameters in mm')
    p.add_argument('--outer', type=float, help='Outside diameter in mm')
    p.add_argument('--inner', type=float, help='Center opening diameter in mm')
    p.add_argument('--offset', type=float, default=10, help='Assumed mounting-hole radial offset from bell edge, mm (VERIFY)')
    p.add_argument('--hole', type=float, default=4.5, help='M4 clearance hole diameter in mm')
    p.add_argument('--thickness', type=float, default=3, help='Reference plate thickness, mm (not used in 2D SVG)')
    p.add_argument('--shape', choices=['circle', 'sunflower'], default='circle',
                   help='Outer edge shape; sunflower adds petals outside --outer')
    p.add_argument('--petals', type=int, default=20, help='Number of petals (sunflower only)')
    p.add_argument('--petal-length', type=float,
                   help='How far petals extend beyond --outer, mm (default 15%% of --outer)')
    p.add_argument('--pattern', choices=['none', 'apollonian'], default='none',
                   help='Decorative score-line pattern on the ring face')
    p.add_argument('--pattern-min', type=float, default=2,
                   help='Smallest circle radius in the pattern, mm')
    p.add_argument('--output', help='Output SVG path')
    a = p.parse_args()
    preset = PRESETS[a.instrument]
    svg(a.instrument, a.bells or preset['bells'], a.outer or preset['outer'],
        a.inner or preset['inner'], a.offset, a.hole, a.thickness,
        a.output or f'{a.instrument}_reflector.svg', a.shape, a.petals, a.petal_length,
        a.pattern, a.pattern_min)

if __name__ == '__main__':
    main()
