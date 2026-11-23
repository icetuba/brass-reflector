# Bell Reflector Generator

`draw_reflector.py` makes a true-size SVG cutting template for a flat, ring-shaped **bell reflector** for trumpet, trombone or euphonium. The ring has three mounting holes for each supported bell size, so one plate fits several bells.

You can send the output straight to a laser cutter. Red lines are cut paths and blue text is engraved labels.

> ⚠️ **The geometry is provisional.** The hole offset from the bell rim (`--offset`) is an assumption, not a measured value. The ring diameters are also unverified. Check the fit on the real instrument before you cut the final material. A paper or cardboard test print is the easiest way.

## Requirements

- Python 3.8+ (it needs `math.dist`)
- Only the standard library is used. There is nothing to install.

## Quick start

```bash
# Default: euphonium preset → euphonium_reflector.svg
python3 draw_reflector.py

# Other presets
python3 draw_reflector.py --instrument trumpet
python3 draw_reflector.py --instrument trombone --output trombone_v2.svg

# Custom bell sizes and ring dimensions
python3 draw_reflector.py --instrument trombone --bells 210 230 250 --outer 310 --inner 160
```

Each run prints a one-line summary and a reminder:

```
Wrote euphonium_reflector.svg: 12 holes, outer 360 mm, inner 190 mm, min outer edge clearance 15.35 mm
WARNING: Offset and ring dimensions are provisional; confirm geometry before fabrication.
```

## Command-line options

All dimensions are in **millimetres**.

| Option | Default | Description |
|---|---|---|
| `--instrument` | `euphonium` | Preset: `trumpet`, `trombone` or `euphonium`. Sets the default bells, outer and inner sizes, and the output file name. |
| `--bells D [D ...]` | from preset | One or more bell diameters. Each one adds 3 mounting holes. |
| `--outer` | from preset | Outside diameter of the ring. |
| `--inner` | from preset | Diameter of the centre opening. |
| `--offset` | `10` | How far each hole sits outward from the bell's rim, measured along the radius. **Provisional; verify it.** |
| `--hole` | `4.5` | Diameter of the mounting holes. 4.5 mm is a standard M4 clearance hole. |
| `--thickness` | `3` | Plate thickness, for reference only. **The 2D SVG does not use it.** |
| `--output` | `<instrument>_reflector.svg` | Where to write the SVG. |

Any option you leave out takes its value from the preset you chose.

## Presets

| Instrument | Bell diameters (mm) | Outer (mm) | Inner (mm) |
|---|---|---|---|
| Trumpet | 123, 127, 136, 140 | 180 | 92 |
| Trombone | 203.2, 215.9, 228.6, 254 (8, 8.5, 9, 10 in) | 300 | 150 |
| Euphonium | 266.7, 279.4, 292.1, 304.8 (10.5, 11, 11.5, 12 in) | 360 | 190 |

All three presets currently produce valid layouts with 12 holes each.

## How the geometry works

The drawing is centred on the origin. In SVG the y axis points down, so an angle of −90° is the top of the drawing.

1. **Hole radius.** For a bell of diameter `B`, its holes sit on a circle of radius `B/2 + offset`.
2. **Hole angles.** Each bell gets 3 holes, 120° apart. With `n` bell sizes, bell `i` starts at angle `−90° + i·360°/(3n)`. This spreads the bells evenly, so the `3n` holes take up `3n` equally spaced angular slots. Example: with 4 bells, there is a hole every 30°, and the bell sizes take turns around the ring.
3. **Labels.** Each hole gets a label showing the **bell diameter** it belongs to. The label sits 7 mm closer to the centre than the hole (font size 3.7 mm), so you can tell which hole is for which bell.

### Validation checks

`svg()` raises a `ValueError` and writes no file if any of these fail:

| Check | Condition |
|---|---|
| Ring sizes | `0 < inner < outer` |
| Hole and offset | `hole > 0` and `offset ≥ 0` |
| Bells | At least one bell, and every bell diameter is greater than 0 |
| Outer edge | Every hole fits completely inside the outer edge. The error says how far it overshoots. |
| Hole spacing | Hole centres are at least `hole + 1` mm apart, which leaves a web of at least 1 mm between holes. |

## Output format

- The SVG `width` and `height` are set in `mm`, so it opens at true size in Inkscape, LightBurn and similar tools. The canvas is `outer + 16` mm square, which leaves an 8 mm margin.
- `<g id="laser-cut">`: the outer circle, the inner circle and every mounting hole. Red stroke (`#ff0000`), 0.1 mm wide, no fill.
- `<g id="engrave-labels">`: the bell-diameter labels. Blue fill (`#0055ff`) in Arial or sans-serif.

Most laser software maps colours to operations. Set red to **cut** and blue to **engrave** or **score**.

## Using it from Python

```python
from draw_reflector import svg

svg(instrument='trumpet', bells=[123, 127, 136, 140], outer=180, inner=92,
    offset=10, hole_diameter=4.5, thickness=3, output='trumpet.svg')
```

## Known limitations and notes

- **Provisional offset.** The module docstring calls this value `contact_offset`. The CLI flag is `--offset`. They are the same thing.
- **No inner-edge check.** The script never checks holes or labels against the centre opening. A large `--inner` with small bells can put holes inside the opening or too close to its edge, and you will get no error. Open the SVG and check.
- **Labels are not checked for collisions.** Labels can overlap the inner edge or each other if you choose tight dimensions.
- **`thickness` is unused.** It is accepted only for reference.
- **Zero values fall back to the preset.** Options like `--outer 0` count as "not given", so the preset value is used and you get no error.
- **Errors show as tracebacks.** When a check fails on the command line, Python prints a full traceback. The actual message is on the last line.
