# brass-reflector

Parametric **bell reflectors** for trumpet, trombone and euphonium. A reflector is a flat ring that mounts on the bell. It has three mounting holes for each supported bell size, so one plate fits several bells.

There are two generators. They use the same presets and put the holes in the same places:

| File | Output | For |
|---|---|---|
| [`draw_reflector.py`](draw_reflector.py) | True-size 2D **SVG**. Red lines are cut paths and blue text is engraved labels. | Laser cutting |
| [`reflector.scad`](reflector.scad) | Solid 3D plate (**STL**) with the labels engraved into the top face | 3D printing |

> ⚠️ **The geometry is provisional.** The hole offset from the bell rim (`offset`) is an assumption, not a measured value. The ring diameters are also unverified. Check the fit on the real instrument before you cut or print a final part. A paper print of the SVG is a cheap first test.

## Requirements

- **SVG:** Python 3.8+ (it needs `math.dist`). Only the standard library is used, so there is nothing to install.
- **STL:** [OpenSCAD](https://openscad.org) 2019.05 or newer, because it needs `assert`. Tested with 2021.01.
  - On macOS the command-line program is inside the app bundle, so it may not be on your `PATH`. Either call it directly, for example `/Applications/OpenSCAD-2021.01.app/Contents/MacOS/OpenSCAD`, or make an alias:
    ```bash
    alias openscad=/Applications/OpenSCAD-2021.01.app/Contents/MacOS/OpenSCAD
    ```

## Quick start

```bash
git clone https://github.com/icetuba/brass-reflector.git
cd brass-reflector

# Laser cutting: SVG (default preset is euphonium → euphonium_reflector.svg)
python3 draw_reflector.py --instrument trumpet

# 3D printing: STL
openscad -o trumpet_reflector.stl -D 'instrument="trumpet"' reflector.scad
```

Both print a summary line and a reminder that the geometry is provisional:

```
trumpet reflector: 12 holes, outer 180 mm, inner 92 mm, ... min outer edge clearance 7.75 mm
WARNING: Offset and ring dimensions are provisional; confirm geometry before fabrication.
```

## Presets

All dimensions are in **millimetres**.

| Instrument | Bell diameters (mm) | Outer (mm) | Inner (mm) |
|---|---|---|---|
| Trumpet | 123, 127, 136, 140 | 180 | 92 |
| Trombone | 203.2, 215.9, 228.6, 254 (8, 8.5, 9, 10 in) | 300 | 150 |
| Euphonium | 266.7, 279.4, 292.1, 304.8 (10.5, 11, 11.5, 12 in) | 360 | 190 |

All three presets produce valid 12-hole layouts in both generators. Any value you set yourself replaces the preset value.

## How the geometry works

The plate is centred on the origin.

1. **Hole radius.** For a bell of diameter `B`, its holes sit on a circle of radius `B/2 + offset`.
2. **Hole angles.** Each bell gets 3 holes, 120° apart. With `n` bell sizes, the bells are offset by `360°/(3n)` from each other, so the `3n` holes are evenly spaced. Example: with 4 bells, there is a hole every 30°, and the bell sizes take turns around the ring. The first bell's first hole is at the top, and the bell sizes go clockwise.
3. **Labels.** Each hole gets a label showing the **bell diameter** it belongs to. The label sits 7 mm closer to the centre than the hole, so you can tell which hole is for which bell.

### Validation checks

If any check fails, no file is written. Python raises a `ValueError`, and OpenSCAD stops with an `assert` error.

| Check | Condition | SVG | STL |
|---|---|:-:|:-:|
| Ring sizes | `0 < inner < outer` | ✓ | ✓ |
| Hole and offset | `hole > 0` and `offset ≥ 0` | ✓ | ✓ |
| Bells | At least one bell, and every diameter is greater than 0 | ✓ | ✓ |
| Outer edge | Every hole fits inside the outer edge. The error says how far it overshoots. | ✓ | ✓ |
| Hole spacing | Hole centres are at least `hole + 1` mm apart (in the STL, `hole + min_web`) | ✓ | ✓ |
| Centre opening | Every hole stays clear of the centre opening | — | ✓ |
| Thickness and engraving | `thickness > 0` and `0 < label_depth < thickness` | — | ✓ |

## Laser cutting: `draw_reflector.py`

```bash
python3 draw_reflector.py                                   # euphonium_reflector.svg
python3 draw_reflector.py --instrument trombone --output trombone_v2.svg
python3 draw_reflector.py --instrument trombone --bells 210 230 250 --outer 310 --inner 160
```

| Option | Default | Description |
|---|---|---|
| `--instrument` | `euphonium` | `trumpet`, `trombone` or `euphonium` |
| `--bells D [D ...]` | from preset | Bell diameters. Each one adds 3 holes. |
| `--outer` | from preset | Outside diameter |
| `--inner` | from preset | Centre opening diameter |
| `--offset` | `10` | How far each hole sits outward from the bell's rim, measured along the radius. **Provisional.** |
| `--hole` | `4.5` | Hole diameter. 4.5 mm is a standard M4 clearance hole. |
| `--thickness` | `3` | For reference only. The SVG does not use it. |
| `--output` | `<instrument>_reflector.svg` | Where to write the SVG |

### SVG output

- The `width` and `height` are set in `mm`, so the file opens at true size in Inkscape, LightBurn and similar tools. The canvas is `outer + 16` mm square.
- `<g id="laser-cut">`: the outer circle, the inner circle and every hole. Red (`#ff0000`), 0.1 mm stroke, no fill.
- `<g id="engrave-labels">`: the bell-diameter labels. Blue (`#0055ff`), 3.7 mm sans-serif.

In your laser software, set red to **cut** and blue to **engrave** or **score**.

### Using it from Python

```python
from draw_reflector import svg

svg(instrument='trumpet', bells=[123, 127, 136, 140], outer=180, inner=92,
    offset=10, hole_diameter=4.5, thickness=3, output='trumpet.svg')
```

## 3D printing: `reflector.scad`

```bash
openscad -o euphonium_reflector.stl reflector.scad
openscad -o trumpet.stl -D 'instrument="trumpet"' -D 'thickness=4' -D 'hole=4.8' reflector.scad
openscad -o custom.stl  -D 'instrument="trombone"' -D 'bells=[210,230,250]' -D 'outer=310' reflector.scad
```

You can also open the file in the OpenSCAD GUI and change the values in the **Customizer** panel. A full render (F6) takes about 15–20 seconds.

| Parameter | Default | Description |
|---|---|---|
| `instrument` | `"euphonium"` | The preset to use |
| `bells`, `outer`, `inner` | `[]`, `0`, `0` | Overrides. Leave them empty or at 0 to use the preset. |
| `offset` | `10` | Same as `--offset`. **Provisional.** |
| `hole` | `4.5` | Hole diameter. Printed holes usually come out small, so consider 4.7 to 4.8 for M4. |
| `min_web` | `1` | Minimum material left between two holes |
| `thickness` | `3` | Plate thickness |
| `labels` | `true` | Turns the engraved labels on or off |
| `label_size`, `label_depth`, `label_inset`, `label_font` | `3.7`, `0.6`, `7`, Liberation Sans Bold | How the labels look and where they sit |
| `ring_fn`, `hole_fn` | `256`, `48` | Curve smoothness, as the number of segments per circle |

Print it flat, with the engraved face up. You don't need supports.

## Known limitations

- **Provisional offset.** It isn't based on measurements. In `draw_reflector.py` the docstring calls it `contact_offset`, which is the same value as `--offset`.
- **Labels aren't checked for collisions.** With tight dimensions, labels can overlap the inner edge or each other. Look at the output before you use it.
- **The SVG script doesn't check the centre opening.** A large `--inner` with small bells can put holes inside the opening, and you get no error. The STL version does check this.
- **Zero values fall back to the preset.** In both generators, `outer`/`inner` set to 0 counts as "not given", so the preset value is used and you get no error.
- **Python errors show as tracebacks.** The actual message is on the last line.
