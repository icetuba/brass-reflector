#!/usr/bin/env python3
"""Parametric SVG reflector for trumpet, trombone, and euphonium.

IMPORTANT: contact_offset is a provisional geometric assumption, NOT a
measured value. Verify fit and all dimensions before cutting.
"""
import argparse
import math
from pathlib import Path
from xml.sax.saxutils import escape

PRESETS = {
    'trumpet': dict(bells=[123, 127, 136, 140], outer=180, inner=92),
    'trombone': dict(bells=[203.2, 215.9, 228.6, 254], outer=300, inner=150),
    'euphonium': dict(bells=[266.7, 279.4, 292.1, 304.8], outer=360, inner=190),
}

def svg(instrument, bells, outer, inner, offset, hole_diameter, thickness, output):
    """Create true-size SVG in millimeters, red cut paths and blue labels."""
    if not 0 < inner < outer or hole_diameter <= 0 or offset < 0:
        raise ValueError('Invalid dimensions')
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
    size = outer+2*margin
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}mm" height="{size}mm" viewBox="{-size/2} {-size/2} {size} {size}">',
             f'<title>{escape(instrument.title())} bell reflector, provisional geometry</title>',
             '<g id="laser-cut" fill="none" stroke="#ff0000" stroke-width="0.1">',
             f'<circle r="{outer/2}"/><circle r="{inner/2}"/>']
    for x,y in xy:
        parts.append(f'<circle cx="{x:.4f}" cy="{y:.4f}" r="{hole_diameter/2:.4f}"/>')
    parts.append('</g><g id="engrave-labels" fill="#0055ff" font-family="Arial,sans-serif" font-size="3.7" text-anchor="middle" dominant-baseline="middle">')
    for (r,a,b), (x,y) in zip(holes,xy):
        # labels are INSIDE each hole, toward center; these indicate BELL diameter
        lr = r - 7
        lx = lr*math.cos(math.radians(a))
        ly = lr*math.sin(math.radians(a))
        parts.append(f'<text x="{lx:.3f}" y="{ly:.3f}">{b:g}</text>')
    parts.append('</g></svg>')
    Path(output).write_text('\n'.join(parts), encoding='utf-8')
    print(f'Wrote {output}: {len(holes)} holes, outer {outer:g} mm, inner {inner:g} mm, min outer edge clearance {min_edge:.2f} mm')
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
    p.add_argument('--output', help='Output SVG path')
    a = p.parse_args()
    preset = PRESETS[a.instrument]
    svg(a.instrument, a.bells or preset['bells'], a.outer or preset['outer'],
        a.inner or preset['inner'], a.offset, a.hole, a.thickness,
        a.output or f'{a.instrument}_reflector.svg')

if __name__ == '__main__':
    main()
