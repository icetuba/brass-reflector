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

/* [Shape] */
// Outer edge: plain circle, or sunflower petals added outside `outer`
shape = "circle"; // [circle, sunflower]
// Number of petals (sunflower only)
petals = 20;
// How far petals extend beyond the outer circle, mm (0 = 15% of outer)
petal_length = 0;

/* [Pattern] */
// Decorative line pattern on the ring face
pattern = "none"; // [none, apollonian]
// Smallest circle radius in the pattern, mm
pattern_min = 2;
// Width of the pattern lines, mm (engraved, or gaps in the two-tone top layer)
pattern_line = 1;

/* [Two-tone (needs sunflower or a pattern)] */
// Add a top colour layer; gaps in it show the base colour as lines
two_tone = false;
// Part to export: all, base (outline colour) or top (petal colour)
part = "all"; // [all, base, top]
// Thickness of the top colour layer, mm
top_thickness = 1.2;
// Width of the outlines around and between petals, mm
line_width = 2;
// Centre vein slit length, as a fraction of petal length (0 = no veins)
vein_length = 0.55;
// Preview colours (the STL has no colour)
base_color = "SaddleBrown";
top_color = "Gold";

/* [Plate] */
// Plate thickness in mm (the base layer when two_tone is on)
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
PL = petal_length > 0 ? petal_length : round(0.15 * OD * 10) / 10;
sunflower = shape == "sunflower";
apollonian = pattern == "apollonian";

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
assert(shape == "circle" || shape == "sunflower", str("Unknown shape: ", shape));
assert(!sunflower || petals >= 3, "Sunflower needs at least 3 petals");
assert(pattern == "none" || apollonian, str("Unknown pattern: ", pattern));
assert(!apollonian || (pattern_min > 0 && pattern_line > 0),
       "pattern_min and pattern_line must be positive");
assert(!two_tone || sunflower || apollonian,
       "two_tone needs shape = \"sunflower\" or a pattern");
assert(part == "all" || part == "base" || part == "top", str("Unknown part: ", part));
assert(part != "top" || two_tone, "part = \"top\" needs two_tone = true");
assert(!two_tone || (top_thickness > 0 && line_width > 0),
       "two_tone needs top_thickness > 0 and line_width > 0");
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
         " mm, inner ", ID, " mm, thickness ", thickness, " mm",
         sunflower ? str(", sunflower ", petals, " petals x ", PL,
                         " mm (overall ", OD + 2 * PL, " mm)") : "",
         ", min outer edge clearance ", outer_clear, " mm"));
// ---------------------------------------------------------------------------
// Apollonian gasket (same construction as draw_reflector.py).
// A Steiner chain of n equal circles fits between the centre opening and a
// boundary circle of radius GR; n is the smallest count that keeps GR within
// gasket_margin of the outer edge. Each gap is filled recursively with
// Descartes' circle theorem down to radius pattern_min.
// Circles are [curvature, x, y]; the boundary has negative curvature.

gasket_margin = 2;

function steiner_R(n) = let (s = sin(180 / n)) (ID / 2) * (1 + s) / (1 - s);
function steiner_n(n = 3) =
    n > 500 ? undef : steiner_R(n) <= OD / 2 - gasket_margin ? n : steiner_n(n + 1);

function cmul(p, q) = [p[0] * q[0] - p[1] * q[1], p[0] * q[1] + p[1] * q[0]];
function csqrt(p) = let (m = norm(p))
    [sqrt(max(0, (m + p[0]) / 2)), (p[1] < 0 ? -1 : 1) * sqrt(max(0, (m - p[0]) / 2))];
function cz(c) = [c[1], c[2]];

function tangent_error(c, t) =
    let (r = 1 / c[0],
         want = t[0] > 0 ? abs(1 / t[0] + r) : abs(-1 / t[0] - r))
    abs(norm(cz(c) - cz(t)) - want);

function descartes(a, b, c) =
    let (k4 = a[0] + b[0] + c[0] + 2 * sqrt(max(0, a[0] * b[0] + b[0] * c[0] + c[0] * a[0])),
         s = a[0] * cz(a) + b[0] * cz(b) + c[0] * cz(c),
         p = a[0] * b[0] * cmul(cz(a), cz(b)) + b[0] * c[0] * cmul(cz(b), cz(c))
           + c[0] * a[0] * cmul(cz(c), cz(a)),
         root = csqrt(p),
         z1 = (s + 2 * root) / k4,
         z2 = (s - 2 * root) / k4,
         c1 = [k4, z1[0], z1[1]],
         c2 = [k4, z2[0], z2[1]],
         e1 = tangent_error(c1, a) + tangent_error(c1, b) + tangent_error(c1, c),
         e2 = tangent_error(c2, a) + tangent_error(c2, b) + tangent_error(c2, c))
    e1 <= e2 ? c1 : c2;

function gasket_fill(a, b, c) =
    let (d = descartes(a, b, c))
    1 / d[0] < pattern_min ? [] :
    concat([d], gasket_fill(a, b, d), gasket_fill(b, c, d), gasket_fill(a, c, d));

GN = apollonian ? steiner_n() : 0;
GR = apollonian ? steiner_R(GN) : 0;

function gasket_circles() =
    let (rho = (GR - ID / 2) / 2,
         d = (GR + ID / 2) / 2,
         bound = [-1 / GR, 0, 0],
         hub = [2 / ID, 0, 0],
         chain = [for (j = [0 : GN - 1])
                     let (a = 90 - 360 * j / GN) [1 / rho, d * cos(a), d * sin(a)]])
    concat(chain,
           [for (j = [0 : GN - 1])
               let (A = chain[j], B = chain[(j + 1) % GN])
               each concat(gasket_fill(hub, A, B), gasket_fill(bound, A, B))]);

gasket = apollonian ? gasket_circles() : [];

assert(!apollonian || GN != undef, "No room for the Apollonian pattern; increase outer");
if (apollonian)
    echo(str("Apollonian pattern: ", len(gasket), " circles (", GN, " in the main ring)"));

if (two_tone)
    echo(str("Two-tone: total height ", thickness + top_thickness,
             " mm. Single extruder: change filament at Z = ", thickness, " mm."));
echo("WARNING: Offset and ring dimensions are provisional; confirm geometry before printing.");

// ---------------------------------------------------------------------------
// Model

eps = 0.01;

// Sunflower edge (same curve as draw_reflector.py). Valleys touch the outer
// circle and tips reach OD/2 + PL. The first tip is at the top.
function petal_profile(u) = pow(cos(90 * u), 0.6) * (1 - 0.25 * abs(u));

petal_samples = 64;
function sunflower_points() = [
    for (k = [0 : petals * petal_samples - 1])
        let (phase = k / petal_samples,
             u = ((phase + 0.5) % 1) * 2 - 1,
             r = OD / 2 + PL * petal_profile(u),
             a = 90 - 360 * k / (petals * petal_samples))
        [r * cos(a), r * sin(a)]
];

module outline() {
    if (sunflower) polygon(sunflower_points());
    else circle(d = OD, $fn = ring_fn);
}

// Top colour layer (2D): covers the whole top face, so the base colour shows
// only as lines: around the outside edge, between petals, a circle between the
// ring and the petals, a rim around the centre opening and each hole, a vein
// slit up each petal, and the labels (cut through this layer).
module vein() {
    r0 = OD / 2;
    r1 = OD / 2 + vein_length * PL;
    polygon([[r0, -line_width / 2], [r1, 0], [r0, line_width / 2]]);
}

module top_layer_2d() {
    difference() {
        offset(r = -line_width) outline();
        // Rim around the centre opening
        circle(r = ID / 2 + line_width, $fn = ring_fn);
        // Circle between the ring and the petals
        if (sunflower)
            difference() {
                circle(r = OD / 2 + line_width, $fn = ring_fn);
                circle(r = OD / 2, $fn = ring_fn);
            }
        pattern_lines_2d();
        // Rim around each mounting hole
        for (h = holes)
            translate([h[0], h[1]]) circle(d = hole + 2 * line_width, $fn = hole_fn);
        // Labels
        if (labels) label_shapes();
        if (vein_length > 0)
            for (i = [0 : petals - 1])
                rotate(90 - i * 360 / petals) vein();
    }
}

// Bell-diameter labels (2D), placed label_inset toward the centre from each hole
module label_shapes() {
    for (h = holes)
        let (lr = h[2] - label_inset)
            translate([lr * cos(h[4]), lr * sin(h[4])])
                text(str(h[3]), size = label_size, font = label_font,
                     halign = "center", valign = "center");
}

// Pattern lines (2D): an outline ring of width pattern_line for every gasket
// circle, plus the gasket's boundary circle.
module line_ring(r, w) difference() {
    circle(r = r + w / 2);
    circle(r = max(eps, r - w / 2));
}

module pattern_lines_2d() {
    if (apollonian) {
        line_ring(GR, pattern_line, $fn = ring_fn);
        for (c = gasket)
            translate([c[1], c[2]])
                line_ring(1 / c[0], pattern_line, $fn = max(24, min(ring_fn, round(6 / c[0]))));
    }
}

module base_plate() difference() {
    // Ring
    difference() {
        linear_extrude(height = thickness) outline();
        translate([0, 0, -eps]) cylinder(d = ID, h = thickness + 2 * eps, $fn = ring_fn);
    }

    // Mounting holes
    for (h = holes)
        translate([h[0], h[1], -eps])
            cylinder(d = hole, h = thickness + 2 * eps, $fn = hole_fn);

    // Engraved labels showing the bell diameter each hole belongs to.
    // In two-tone mode they're cut through the top layer instead.
    if (labels && !two_tone)
        translate([0, 0, thickness - label_depth])
            linear_extrude(height = label_depth + eps) label_shapes();

    // Engraved pattern lines (single colour only; two-tone cuts them in the top layer)
    if (apollonian && !two_tone)
        translate([0, 0, thickness - label_depth])
            linear_extrude(height = label_depth + eps) pattern_lines_2d();
}

if (part == "all" || part == "base")
    color(base_color) base_plate();

if (two_tone && (part == "all" || part == "top"))
    color(top_color)
        translate([0, 0, thickness])
            linear_extrude(height = top_thickness) top_layer_2d();
