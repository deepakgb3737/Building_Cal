# EasyFloor Doors

Choose **Shapes > Door** in the existing drawing toolbar, then tap the canvas. Placement
near a wall uses that wall's direction. Enter the width in the current plan unit.
Tap Apply to place the symbol; Cancel leaves the drawing unchanged.

- Drag a door's leaf or closed baseline to reposition it.
- Tap the door or use **Edit door** to change its width, rotation, hinge and swing.
- Rotation supports 0-360 degrees; opening supports 0-180 degrees.
- **Closed**, **90 degrees**, and **Fully open** provide quick opening choices.
- **Hinge on right** changes the hinge end. **Open to other side** reverses swing.
- The contextual **Open door / Close door** button toggles between 90 and 0 degrees.
- Delete removes only the selected door. Undo/Redo includes all door changes.
- Starting a two-finger gesture cancels an in-progress door move before navigation.
- Existing document Save/Open includes door symbols; older documents have no doors.

## Boundaries

Doors are independent plan symbols, not wall openings. They do not cut, split,
connect, resize or change the lengths of walls. They do not participate in wall
snapping or constraints. Moving a room/wall does not move its independently placed
door symbol; reposition the door separately. Multiple-door group movement is not
part of this initial tool.

All positions and widths are world millimetres. Zoom changes only rendering and
screen-space hit tolerance. The door model is in `logic/drawing_doors.dart`, the
editor/rendering are in `ui/door_dialog.dart` and `ui/door_painter.dart`. Shared
history and document snapshots carry a separate `DrawingDoors` layer. Missing
legacy `doors` fields load as an empty layer; malformed door records are rejected.
Untouched width fields preserve full stored precision, even if the chosen unit
shows a rounded value.

## Verification

Automated tests cover leaf geometry, both hinges and swing directions, rotated
and closed/open positions, validation, legacy loading, saved document reopening,
geometry isolation, dimension editing, movement/deletion, Undo/Redo, cancelled
placement/edit/drag, two-finger interruption, hit tolerances at three scales, and
narrow/landscape keyboard-open forms. Physical-device testing has not been done.
