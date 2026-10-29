# Smart 90-degree drawing and connected walls

## Draw and Wall continuation

Both Draw (freehand) and Wall now continue when dragged from an unselected,
unlocked open endpoint. The final tip of the most recently committed open stroke
can also continue through a newly connected shared junction. Rough sketches get
this behavior after their existing review is accepted. Tap the corner first to
select and reshape it instead; other shared corners and wall interiors retain
the explicit hold-to-branch gesture. Automatic continuation does not bypass
attached length locks or explicit endpoint-resize handles.

The existing 90-degree/straight-line assistance is reused, including connected
diagonal walls; Free Angle and intentional diagonal strokes remain available.
Connected-wall and preceding-stroke references now use the configured angular
tolerance consistently for long runs and at different zoom levels, rather than
also requiring their tips to stay within six screen pixels. The closest eligible
connected reference takes priority over unrelated alignment targets. Unrelated
parallel/cardinal references retain their spatial limit. Existing endpoint snaps
still take priority in the drawing gesture; Free Angle disables these corrections.
Each continued stroke is one normal geometry/history operation. Two-finger
navigation cancels its preview without committing it. The recent-tip hint is
temporary UI state, cleared on document replacement and Undo/Redo, not a new
wall constraint or stored room object. No toolbar rebuild or new mode is added.

Regression tests cover sequential strokes, T-to-cross continuation, accepted
multi-corner sketches, tap-first resizing, locked endpoints and interrupted
navigation. These automated tests do not establish physical-phone behavior.

## Root causes and focused changes

- All endpoint drags previously entered corner editing, so drawing successive
  individual walls required a hold. The first repair covered only Wall; the
  continuation update above now covers Draw too and the just-drawn junction.
  Tap the endpoint first to select it for editing. Other shared corners and wall
  interiors retain hold-to-branch. No additional mode or toolbar was added.
- Default angle assistance previously considered only board axes. It now also
  considers the attached wall direction (including a midpoint connection) and the
  preceding uncommitted stroke segment. The connected-angle improvement above
  removes the extra spatial cutoff only for these attached/local references;
  unrelated alignments retain both thresholds. Arbitrary angles remain available.
- The existing assistance toggle identifies 90-degree assistance / Free Angle.
  Existing shared-corner topology, snap targets, guides, contextual angles,
  geometry validation and history remain authoritative. No C-specific geometry,
  inferred room objects or room fill was introduced.

## Automated verification

New tests: `test/features/easy_floor/smart_right_angle_test.dart`.

| Scenario | Evidence |
| --- | --- |
| Rectangle from separate connected walls | New widget test; four shared vertices |
| L in both drawing directions | New sequential-stroke widget tests |
| Open C in both directions | New widget tests; four segments, five vertices, no enclosure |
| Deliberately close the C endpoints | New widget tests; closure only after the final stroke |
| Open U | New sequential-stroke test; two open endpoints |
| Diagonal and 180-degree continuation | New unit/widget tests; no axis forcing |
| 90-degree snapping / Free Angle | New attached/previous/midpoint reference tests; existing cardinal and line-alignment suites |
| Live right-angle feedback | New widget test checks actual preview angle, contextual 90-degree angle and guides |
| Midwall / endpoint connection | Existing endpoint-connection and free-wall-movement suites; selected endpoint setup updated for the Wall interaction |
| Connected translation, movement away | Existing free-wall-movement suite |
| Near-target rejection | Existing out-of-range snap, endpoint and quality-foundation tests |
| Zoom, pan, dimensions, history | Existing navigation, units, pinch and movement suites; C Undo/Redo checks |
| Second finger interrupts a new branch | New widget test; original geometry restored and preview discarded |
| Duplicates and geometry integrity | Existing junction, reliability and repeated-edit integrity suites |

The focused ten-test suite passes. The complete suite passes all 700 tests after
all changes. Static analysis has no errors or warnings; its 62 existing info-level
findings still cause the default analyzer command to exit nonzero. Headless
Chrome startup and hot reload succeeded (156 ms); this is not physical-phone
validation.

## Remaining validation / interaction boundary

No Android/iOS physical-device checks were performed for this change. Finger
thresholds, stylus behavior and discoverability still need on-device review.
Endpoint creation versus corner editing is inherently ambiguous: the existing
Wall tool favors continuing an unselected open end; tap first to reshape it.
This policy does not replace Draw-mode corner editing or shared-junction editing.

### Single-wall continuation after lifting

In Draw or Wall drawing, drag outward from the latest open tip to continue it. A touch
slightly inside that tip also continues when the movement follows the wall's
outward direction. The new segment starts at the existing shared corner; the
original wall is unchanged. Tap a wall first to move it deliberately, or tap its
corner first to reshape it. Mid-wall drags, locked walls and explicit resize
handles retain their editing behavior. No new tool or mode is required.

With right-angle assistance enabled, the same near-tip forgiveness also applies
to a new perpendicular wall in either direction. It applies only at the latest
unselected, unlocked open tip, not at wall midpoints or deliberately selected
walls. Free Angle does not acquire this perpendicular gesture preference.
Regression tests cover horizontal/vertical starts, all four turn directions,
shared corner identity, unchanged original endpoints, and exact Undo/Redo in both
Draw and Wall. A selected freehand wall still translates normally near its tip,
and cancelling that drag restores the original geometry exactly.

### Continue connected walls after Undo/Redo

History snapshots now retain the transient drawing endpoint alongside the wall,
annotation and door layers. Undoing a continuation restores the original junction
as the drawing tip, so the next drag adds a wall instead of moving that junction.
Both Draw and Wall use this context. Geometry edits clear it unless the operation
explicitly supplies a newly drawn endpoint; text/door edits preserve it. Document
replacement clears transient intent. This is session interaction state, not an
extra wall, constraint, saved measurement or toolbar mode.

Regression tests exercise T-to-cross continuation after Undo/Redo/Undo in both
tools, unchanged existing corners, non-wall history edits, stale endpoint removal,
no-op commits and document-history reset.
