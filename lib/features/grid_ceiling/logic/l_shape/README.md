# Isolated L-shaped grid ceiling engine

**Disabled in normal builds.** All backend and UI code is retained. See
`docs/GRID_CEILING_L_SHAPE_DISABLED.md` at the project root for the gate and tests.

This is a separate backend, not a replacement for the rectangular calculator.
When explicitly enabled for development, it is selected by Rectangle / L-shape inside the existing Grid Ceiling screen.
L-shaped UI lives separately in `ui/l_shape/`; both drawing views consume the
returned sections, not a second calculation. Rectangle remains the default.

To remove L-shape support, first remove its imports, shape selector, arm fields
and result branch from `ui/grid_ceiling_screen.dart`, then remove the two
`l_shape` folders and their tests. The rectangular engine has no L-shape imports.

## Files

- `l_ceiling_room.dart`: validated mm dimensions, missing-corner orientation,
  boundary and grid-cell clipping. No Flutter dependencies.
- `l_ceiling_calculator.dart`: continuous grid generation, clipping and material
  estimates. Reuses existing placement helpers, cross-T substitution rules and
  the tile offcut optimizer without modifying them.
- `l_ceiling_result.dart`: immutable sections, tile footprints and counts for
  later UI integration. Counts are derived from these same sections.

## Dimension mapping

- Overall width: horizontal bounding dimension.
- Overall length: vertical bounding dimension.
- Vertical arm width: measured along the width axis, less than overall width.
- Horizontal arm depth: measured along the length axis, less than overall length.
- Missing corner: top-left, top-right, bottom-left or bottom-right.

Overall dimensions follow the current application's 800–40000 mm validation.
Arms must be finite, positive and smaller than their respective overall axis.
They are not swapped when orientation changes. Very narrow arms may need special
installation details and should not be treated as a structural approval.

## Alignment convention

Centered mode centers the existing grid on the overall bounding dimensions,
not independently on each arm. One-side mode uses the same 1200/600 mm starting
rules as the rectangular calculator. All geometry is built in the top-right
missing-corner frame, then mirrored together for other orientations. Thus
one-side origin mirrors with the room; it is not always the screen's top-left.
No additional room/arm grid is superimposed.

## Quantity assumptions and limits

- Runners stop at actual walls. Lines coincident with notch boundaries are not
  duplicated over wall angles. Dividers are divided at the actual cross-T rows.
- Main stock purchasing preserves the supplied aggregate formula:
  `ceil(total clipped main length / 3048)`. It is a linear-length estimate, not
  a connection-aware cutting schedule or guarantee that all offcuts are usable.
- Wall angles use the complete six-edge perimeter / 3048, rounded up. For a
  rectangle with a corner removed the perimeter equals `2 × (width + length)`;
  the area does not equal the overall bounding rectangle's area.
- Hangers preserve the current perimeter / 1200 estimate. It is not an engineered
  suspension layout. Supplier and site checks remain necessary.
- Cross-T substitutions preserve the existing compatible divider-junction
  assumption; check `requiresPerimeterJunction` before ordering.
- A tile straddling the inner corner stays one notched footprint, not two tiles.
  Footprints describe the 600 mm grid openings. Source stock remains 595 mm;
  fitting clearances follow the current rectangular calculation convention.
- Offcuts are reused globally across the L, including opposite edges, with an
  optional per-cut allowance. Notched cuts conservatively reserve their bounding
  rectangle. The existing guillotine optimizer is not a certified minimum-nesting
  solution. Cut dimensions describe that stock rectangle, not notch instructions.
- UI must label purchases as estimates, expose the junction warning, and render
  the returned sections/footprints rather than reconstructing two rectangles.

## Example

```dart
final result = LCeilingCalculator.calculate(
  LCeilingRoom(
    widthMm: 3600,
    lengthMm: 3000,
    verticalArmWidthMm: 1800,
    horizontalArmDepthMm: 1200,
    missingCorner: MissingCorner.topRight,
  ),
  mode: PlacementMode.oneSide,
);
```

This example has 7.56 m², 21 full tile positions, 6 four-foot cross-T pieces,
12 two-foot pieces, and 4200 mm of main runners (2 stock lengths by the supplied
aggregate formula). Automated tests cover these counts, notched cells, mirrored
orientations, offcut reuse, invalid inputs, randomized clipping/area invariants
and unchanged rectangular results. Installation has not been physically tested.
