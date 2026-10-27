# PVC Ceiling

## Shape-Aware Planning

Home opens a native Flutter calculator for Rectangle, L-shape, T-shape, U-shape,
Angled wall and Cut corner rooms. This merges the supplied `PVC multi .html`
into the existing calculator; it does not embed a website or a separate app.

Choose the room shape, enter the lettered dimensions in decimal feet, choose
10-ft / 12-ft / mixed stock, and Calculate. L-shapes support four mirrored
step-in corners. Optional E centers the T stem or U opening when left blank.
Each shape retains its entered values when switching shapes during the session.

The diagram and field letters come from the same room model. Focusing a field
highlights its edge. Invalid input hides the diagram rather than displaying a
stale/default shape. Validation appears beside the affected field when calculating.
Inputs scroll into view when focus or keyboard geometry changes. Controls,
labels, previews and results adapt to narrow and landscape viewports.

Measurement inputs use the shared `AppNumberField` with an always-visible wall
letter and `ft` unit, a full name above, and a larger right-aligned value. Empty
optional inputs keep their letter/unit visible. PVC uses the shared compact
field variant with 48-pixel minimum height and two columns on standard phone
widths; enlarged text falls back to one column. Field columns adapt to text
scaling, and cramped keyboard viewports prioritize the editable value when the
complete label and field cannot fit. Other numeric fields retain their existing
appearance unless they explicitly enable these shared presentation options.

### UI Refinement

The measurement preview is a tappable thumbnail beside the section title,
not a full-width diagram above the inputs. Tapping opens a larger scrollable
guide; closing it preserves entered values and the current shape. Letter badges
use collision-aware placement and leader lines when moved;
the active letter stays in the same position while focusing its field. Shape
and stock selectors share a row on wide screens and stack on narrow screens.
Calculating reveals the result summary; invalid input focuses its field.

Plans and cutting diagrams use bounded, fitted viewports rather than forced
700/520 px widths or potentially screen-sized vertical diagrams. Pinch or the
zoom controls reveal detail; Fit restores the full view. Page scrolling remains
available over a fitted diagram, and dragging explores a zoomed diagram. Camera
transforms do not change dimensions, cutting quantities or any calculation data.
There are no calculation-engine changes in this UI refinement.

For L-shapes, C is the **step across** and D is the **step down**, as defined by
this supplied HTML. C is not an arm-width field from EasyFloor's separate preset
workflow. The preview always shows the edge being measured.

## Calculation And Drawing Boundaries

- `logic/pvc_room.dart`: field definitions, validation, polygon geometry, areas,
  letter-to-edge mappings, scanning and row coverage envelopes. No Flutter imports.
- `logic/pvc_ceiling_calculator.dart`: existing exact cutting-stock solver,
  rectangular compatibility entry, stock selection and grouped cutting plans.
- `logic/pvc_packing.dart`: multi-piece splits, candidate limits and best-fit
  decreasing fallback for large or varied cut demands.
- `logic/pvc_polygon_optimizer.dart`: searches both plank orientations across
  all polygon rows and chooses one consistent material/placement result.
- `logic/pvc_ceiling_models.dart`: row segments, per-row piece lists, quantities,
  linear waste and blade-aware tape readings.
- `ui/`: collects input, formats units and renders that same calculated layout
  and cutting plan. Painters clip planks to the polygon, including openings.

PVC material colors remain in `lib/core/theme/build_calc_colors.dart`, exposed
through `AppColors`. Inputs, typography, errors and controls use shared UI/theme
components. No nested MaterialApp, local palette or new package is introduced.

## Supplied Rules And Limits

Dimensions are 0.5–100 ft per entered wall. Angled side walls B/C may be zero for
a pointed corner, but the base and room area must remain positive. Relationship
validation rejects impossible steps, gaps and stems. T-shape total depth can be
up to 200 ft because B and D are separate entered walls.

Plank cover width remains 300 mm (`300 / 304.8` ft), with a 1/8-inch blade
allowance, 10-ft / 12-ft stock and the supplied edge-row rules. Candidate joint
pieces normally have a 2-ft minimum; polygon boundary pieces can be shorter in
complex profiles, following the supplied fallback behavior. Long runs now use
more than two pieces. Finishing takes priority: both orientations are compared
by joint count, then purchased stock length, then stock count. Each span uses
the fewest pieces available from the generated candidates; extra splits are not
introduced merely to reuse offcuts. Pieces are still packed across all rows.
This can increase purchased material/waste in exchange for fewer joints. No
labour or joint-price estimate is implied because those rates are not inputs.

Plank installation direction defaults to Auto (the same joint-first comparison).
Choose Along length (A direction) or Across width (B direction) to evaluate only
that room axis. This is independent of the L-shape missing-corner choice. Changing
direction after calculation reruns the same optimizer and updates quantities,
joints, layout and cutting guide together; inputs are retained. The plan may be
rotated on screen to keep the selected plank run left-to-right, and the result
states the original room direction. If the selected direction has no valid row
layout, it reports no valid layout rather than silently switching direction.

### Optional Centre Or Custom Joint Line

Joint placement defaults to Auto and preserves the existing optimizer. The
separate `logic/pvc_joint_rules.dart` implements Centre and Custom placement.
Choose an explicit A or B installation direction before using either rule.
Centre uses half the overall room extent in that direction (21 ft becomes
10.5 + 10.5 ft), not an independent centre for each irregular row.
Custom uses a distance in feet from the selected original-diagram side:
left/right for A, top/bottom for B. A clipped preview shows the requested line
before Calculate; no extra confirmation popup is needed.
The live preview labels distances in feet from both opposite room sides. The
line remains faintly visible through cutouts, with stronger strokes inside the
room; changing a custom distance updates both the line and its readings.

Every row span crossing the line must have a joint there. Rows not crossing it
remain separate spans. Longer sides may need additional joints to fit 10/12 ft
stock. Joint fragments below the existing 2 ft minimum are rejected with an
explanation; the engine never silently moves the line. End-wall pieces on other
rows retain existing rules. Joint position, ordered installed pieces, stock
packing, quantities and cutting guides come from the same result. Rounding is
still 0.001 ft. This bounded search reuses offcuts within the chosen placement;
it does not guarantee minimum installed cost or a global cutting optimum.
Any input change clears the previous result until recalculated.

For the default mixed-stock examples, this changes L from 6 to 0 joints,
U from 20 to 0, and T from 17 to 7. L purchases rise from 176 to 192 linear ft;
U from 168 to 178; T from 162 to 178. These are examples of the explicit
finishing/material trade-off, not a claim that total installed cost is lower.

The exact dynamic program is used for at most five sizes and 150,000 demand
states. Larger problems use the supplied small-/large-stock best-fit heuristics.
Split candidates and combinations are capped (400 combinations). This is a
bounded optimizer, not a guarantee of the global minimum for every possible
staggered installation. Linear waste includes remaining stock, not all trimming
area along angled or stepped walls. The room area is shown separately.

### Deliberate Coverage Correction

The HTML samples 0.01 ft inside row edges, which can undersize a plank next to
a sloping wall. Dart instead computes exact one-sided spans at row boundaries
and every internal polygon vertex. It therefore covers the complete row before
edge trimming. Default angled cut lengths differ slightly from the HTML for
this reason. Joint-first selection can also differ from the HTML stock counts.

The supplied piece precision (0.001 ft), quarter-inch size formatting and
eighth-inch tape-reading formatting remain. Account for real installation
clearances and verify cutting marks on site; rounded labels are not fabrication
certification. No structural/support design is inferred from these quantities.

## Verification

The original HTML fixtures are retained for historical comparison. Separate
joint-first fixtures cover the six defaults under the finishing-first policy.
Regression tests check stock counts, orientation, row counts, joints, quantities,
blade accounting and grouped cuts. Orthogonal cut sizes match the HTML; angled
coverage tests verify the documented correction rather than matching undersized
reference lengths. Tests also cover mirrored L-shapes, optional offsets,
conflicting dimensions, pointed corners and multi-piece long runs.

Widget tests exercise all six shapes at 280px portrait and 740px landscape,
enlarged text, shape switching, exact preview mapping, stale-preview suppression,
keyboard focus visibility and results consuming the same layout as the painter.
A pixel test checks that the U opening contains no drawn plank material.
Automated tests and a browser hot reload do not establish physical-device or
field-installation accuracy.
