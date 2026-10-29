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
Centre/Custom highlights the installation-direction field and scrolls it into
view. It prompts for A/B while Auto is selected, confirms the selected direction,
and returns to normal styling when joint placement returns to Auto.
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

### Named Local Projects

The PVC app-bar menu provides Save project and Saved projects. Calculate a valid
layout first, then enter a name (1–80 characters). Saving the same open project
name updates its saved copy; a different name creates another project. Duplicate
names are rejected without overwriting another project.

Projects preserve the active room shape/dimensions, L-corner orientation, stock
choice, plank direction and centre/custom joint settings. Open restores those
inputs and recalculates with the current engine; cached quantities are not
treated as authoritative. Future formula changes may therefore change results.
Opening asks before replacing unsaved input changes. Deleting asks for
confirmation and removes only the stored copy, not the open calculation.

`logic/pvc_projects.dart` validates versioned JSON before applying it. It reuses
the existing platform storage adapters with the separate `pvc_ceiling_projects`
namespace; EasyFloor's original paths/keys remain unchanged. Native writes use
same-directory temporary-file rename; browser writes use localStorage. Invalid
saved entries cannot be opened, but remain visible for deliberate deletion.
Storage errors are shown without replacing current inputs or silently falling
back to in-memory-only storage.

This is manual, local saving, not cloud backup or cross-device synchronization.
Removing the app, clearing its data, or clearing browser storage can remove
projects. Browser storage is specific to the site origin/browser profile.
Inactive shape drafts and unsaved edits are not persisted automatically.

### Diagram Stock Labels

Installed cut lengths remain the primary labels. Smaller `10f plank` / `12f plank`
labels identify the source stock assigned from the actual cutting plan, not from
the cut length alone. Equal-sized cuts can originate from different stock sizes.
Assignment consumes the plan's cut inventory in row/segment/piece order without
changing quantities or geometry. Labels stack where row height permits or use
an inline small label; crowded pieces retain the cut length instead of overlapping
text. The diagram footer explains the distinction. Zoom remains available.

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

## Share the complete report as PDF

After a valid calculation, choose **PVC projects > Share PDF**. The existing
project name is used if available; unsaved results can also be exported. Changing
an input invalidates the result and disables PDF sharing until recalculated.

PVC and EasyFloor now share `lib/core/pdf/pdf_export.dart`. Its single-page API
remains compatible, and its streamed multi-page API packages the complete PVC
report without rebuilding formulas or recalculating the optimisation.

The report includes:
- Purchase quantities for 10 ft and 12 ft planks, total stock and installed length.
- Boxed room overview: original length/width in feet and metres, area in square
  feet and square metres. Irregular rooms distinguish overall extents from actual
  area. Separate compact 12 ft and 10 ft purchase-quantity boxes precede totals,
  wastage, rows and joints.
- All room input dimensions, labelled original-shape preview, and L-step corner.
- Enlarged room guides and PDF previews show each input letter with its actual
  edge measurement in feet (up to two decimals), including calculated optional
  shoulders/arms. Compact input thumbnails retain letters only; crowded enlarged
  guides use separated callouts with leader lines.
- Requested and actual installation direction, stock selection, joint mode,
  requested measurement side and actual aligned joint position when applicable.
- The existing colour-coded ceiling diagram, including stock-source labels.
- Every cut pattern and quantity, whole-plank instructions, scrap, numbered cutting
  diagrams and tape readings from the existing backend's cut spans/kerf allowance.
- Installation schedule with edge-row cover widths, spans, installed piece lengths
  and source stock. Only consecutive equivalent rows with the same source stocks
  are grouped; every row and piece remains represented.

Long cutting guides and schedules continue onto additional pages instead of being
cropped. The shared engine rejects reports exceeding 200 pages or failed render
streams; it never returns a partial PDF. All PDF text uses explicit shared canvas
colours because widget-inherited text colour is unavailable during printing.

Diagrams are approximately 200-DPI raster pages fitted onto A4, not vector/CAD or
construction-scale drawings. Existing dimension rounding is retained. No costs or
uncalculated accessory quantities are invented. Physical-device share delivery is
not covered by mocked tests. Cancellation/failure preserves inputs, results and
saved projects. Sample reports were rasterised and visually inspected; automated
tests cover all shapes, joint options, row/stock coverage and stale-result guards.
