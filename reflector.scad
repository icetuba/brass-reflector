// Parametric bell reflector for trumpet, trombone and euphonium (3D-print version).
// An OpenSCAD port of draw_reflector.py. Same layout, but it outputs a solid
// plate with the bell-diameter labels engraved into the top face.
//
// IMPORTANT: `offset` is a provisional geometric assumption, NOT a measured
// value. Verify fit and all dimensions before printing a final part.
//
// Command line example:
//   openscad -o trumpet.stl -D 'instrument="trumpet"' reflector.scad

/* [Instrument] */
// Preset that supplies the default bells, outer and inner sizes
instrument = "euphonium"; // [trumpet, trombone, euphonium]

/* [Overrides (leave empty or 0 to use the preset)] */
// Bell diameters in mm; each one adds 3 mounting holes
bells = [];
// Outside diameter in mm
outer = 0;
// Centre opening diameter in mm
inner = 0;

/* [Mounting holes] */
// Radial distance from the bell rim to the hole centre, mm (PROVISIONAL - VERIFY)
offset = 10;
// Hole diameter in mm (4.5 = M4 clearance; add ~0.2-0.3 for printer shrinkage)
hole = 4.5;
// Minimum material left between holes and between a hole and an edge, mm
min_web = 1;

/* [Plate] */
// Plate thickness in mm
thickness = 3;

/* [Labels] */
// Engrave bell-diameter labels into the top face
labels = true;
// Text height in mm
label_size = 3.7;
// Engraving depth in mm
label_depth = 0.6;
// How far the label sits toward the centre from its hole, mm
label_inset = 7;
// Font for labels
label_font = "Liberation Sans:style=Bold";

/* [Quality] */
// Segments for the ring edges
ring_fn = 256;
// Segments for each hole
hole_fn = 48;

// ---------------------------------------------------------------------------
// Presets (same values as draw_reflector.py)

function preset(name) =
    name == "trumpet"   ? [[123, 127, 136, 140],         180, 92]  :
    name == "trombone"  ? [[203.2, 215.9, 228.6, 254],   300, 150] :
    name == "euphonium" ? [[266.7, 279.4, 292.1, 304.8], 360, 190] :
    undef;

P = preset(instrument);
assert(P != undef, str("Unknown instrument: ", instrument));

B  = len(bells) > 0 ? bells : P[0];
OD = outer > 0 ? outer : P[1];
ID = inner > 0 ? inner : P[2];
n  = len(B);

// ---------------------------------------------------------------------------
// Hole layout: each bell gets 3 holes 120 deg apart, interleaved so the 3*n
// holes are evenly spaced. Angles are mirrored from the SVG (which is y-down)
// so the print matches the SVG when viewed from above: first hole at the top,
// bell sizes going clockwise.
// Each entry: [x, y, radius, bell_diameter, angle]

holes = [
    for (i = [0 : n - 1], j = [0 : 2])
        let (r = B[i] / 2 + offset,
             a = 90 - i * 360 / (3 * n) - j * 120)
        [r * cos(a), r * sin(a), r, B[i], a]
];

// ---------------------------------------------------------------------------
// Validation (fails the render with a message, like the Python ValueErrors)

assert(ID > 0 && ID < OD, "Invalid dimensions: need 0 < inner < outer");
assert(hole > 0 && offset >= 0, "Invalid dimensions: need hole > 0 and offset >= 0");
assert(n > 0 && min([for (b = B) b]) > 0, "Bell diameters must be positive");
assert(thickness > 0, "thickness must be positive");
assert(!labels || (label_depth > 0 && label_depth < thickness),
       "label_depth must be between 0 and thickness");

outer_clear = min([for (h = holes) OD / 2 - h[2] - hole / 2]);
assert(outer_clear >= 0,
       str("Holes extend beyond outside edge by ", -outer_clear,
           " mm; increase outer or reduce offset"));

// Not checked by the Python version: holes must also clear the centre opening.
inner_clear = min([for (h = holes) h[2] - hole / 2 - ID / 2]);
assert(inner_clear >= 0,
       str("Holes cut into the centre opening by ", -inner_clear,
           " mm; reduce inner or increase offset"));

too_close = [
    for (a = [0 : len(holes) - 2], b = [a + 1 : len(holes) - 1])
        if (norm([holes[a][0] - holes[b][0], holes[a][1] - holes[b][1]]) < hole + min_web)
            [a + 1, b + 1]
];
assert(len(too_close) == 0,
       str("Holes ", too_close[0][0], " and ", too_close[0][1],
           " too close; change bell sizes or layout"));

echo(str(instrument, " reflector: ", len(holes), " holes, outer ", OD,
         " mm, inner ", ID, " mm, thickness ", thickness,
         " mm, min outer edge clearance ", outer_clear, " mm"));
echo("WARNING: Offset and ring dimensions are provisional; confirm geometry before printing.");

// ---------------------------------------------------------------------------
// Model

eps = 0.01;

difference() {
    // Ring
    difference() {
        cylinder(d = OD, h = thickness, $fn = ring_fn);
        translate([0, 0, -eps]) cylinder(d = ID, h = thickness + 2 * eps, $fn = ring_fn);
    }

    // Mounting holes
    for (h = holes)
        translate([h[0], h[1], -eps])
            cylinder(d = hole, h = thickness + 2 * eps, $fn = hole_fn);

    // Engraved labels showing the bell diameter each hole belongs to
    if (labels)
        for (h = holes)
            let (lr = h[2] - label_inset)
                translate([lr * cos(h[4]), lr * sin(h[4]), thickness - label_depth])
                    linear_extrude(height = label_depth + eps)
                        text(str(h[3]), size = label_size, font = label_font,
                             halign = "center", valign = "center");
}
