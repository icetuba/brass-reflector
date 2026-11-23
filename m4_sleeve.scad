// M4 screw sleeve / standoff spacer
// Plain tube that an M4 screw passes through, with raised concentric ribs.

length      = 60;   // mm, overall sleeve length
hole_d      = 4.4;   // mm, M4 clearance (4.3–4.5 for FDM; 4.2 for a snug fit)
outer_d     = 8;     // mm, outside diameter of the core tube
chamfer     = 0.6;   // mm, edge chamfer on both ends (0 to disable)

// Concentric ribs (raised rings around the outside)
rib_width   = 5;     // mm, axial width of each rib at its base
rib_gap     = 5;     // mm, axial gap between ribs
rib_height  = 1;     // mm, how far each rib stands proud of the tube
                     // rib sides are 45° so they print upright with no supports
$fn         = 64;

rib_pitch = rib_width + rib_gap;
rib_count = floor((length + rib_gap) / rib_pitch);
// Center the rib pattern along the sleeve
rib_start = (length - (rib_count * rib_pitch - rib_gap)) / 2;

module rib() {
    hull() {
        cylinder(d = outer_d, h = rib_width);
        translate([0, 0, rib_height])
            cylinder(d = outer_d + 2 * rib_height, h = rib_width - 2 * rib_height);
    }
}

module sleeve() {
    difference() {
        union() {
            // Core tube with chamfered outer edges
            hull() {
                translate([0, 0, chamfer])
                    cylinder(d = outer_d, h = length - 2 * chamfer);
                cylinder(d = outer_d - 2 * chamfer, h = length);
            }
            for (i = [0 : rib_count - 1])
                translate([0, 0, rib_start + i * rib_pitch]) rib();
        }
        // Through hole, with small entry chamfers so the screw starts easily
        translate([0, 0, -1]) cylinder(d = hole_d, h = length + 2);
        translate([0, 0, -0.01])
            cylinder(d1 = hole_d + 2 * chamfer, d2 = hole_d, h = chamfer);
        translate([0, 0, length - chamfer + 0.01])
            cylinder(d1 = hole_d, d2 = hole_d + 2 * chamfer, h = chamfer);
    }
}

sleeve();
