# EasyFloor PDF Sharing

Open **Documents > Share PDF** to export the current complete plan. The plan does
not have to be saved first; saving with a project name also names the PDF.
Choose a destination in the system share interface. On the web, the printing
plugin provides the platform's PDF share/download behavior.

## What the PDF contains

- One A4 page, with portrait or landscape chosen from the full drawing bounds.
- Project name, selected units, wall/door counts and fixed plan-axis orientation.
- Solid, dashed and locked wall styling, using the same shared colors and painters.
- Smart wall dimensions, door symbols with their current opening, and annotations.
- No toolbar, selected objects, edit handles, temporary tape, guides or background grid.
- An explicit fit-to-page/not-to-scale notice and a reminder to verify dimensions on site.

The PDF is a clean, approximately 200-DPI raster drawing inside a standard PDF,
not a vector/CAD file or a screen capture. It is generated independently of the
current screen size, zoom, pan, selection or hidden-measurements preference.
Existing smart dimension placement/deduplication rules remain in effect. Very
large/dense plans still have the readability limits of one fitted A4 page; tiled
pages, construction-scale printing and a segment schedule are not implemented.

## Architecture and safety

- `lib/core/pdf/pdf_export.dart`: shared PDF packaging and safe, bounded filenames. The old feature path is a compatibility alias.
- `ui/floor_pdf_renderer.dart`: print-resolution rendering from a document snapshot.
- `ui/drawing_content_points.dart`: full-content fitting shared with screen Fit.
- Shared drawing/annotation/door painters preserve existing rendering and formulas.
- `pdf` creates the PDF; `printing` presents platform sharing. No export server is used.

Export is disabled while a gesture, sketch/preset preview, dialog or document
operation is active, and when the plan is empty. The busy guard prevents duplicate
exports. Creation or platform-sharing failures display an error and retain the
complete drawing and Undo/Redo history. File sharing does not save or overwrite
an EasyFloor project. Sharing completion is controlled by the platform/destination;
opening the share interface is not proof that a recipient received the file.

The existing vendored EasyFloor dependency requires XML 6, so PDF 3.13/XML 7 cannot
be used yet. PDF 3.12 uses archive <4.1; the app constrains image to 4.10.x because
image 4.11 calls an archive API unavailable under that constraint. Revisit this
compatibility constraint when the XML/PDF dependency chain is upgraded together.

## Verification

Automated tests cover PDF headers, image resolution, both orientations, camera
independence, symbols/notes-only plans, empty-plan rejection, safe filenames,
platform sharing and error recovery, and preservation of geometry and history.
A generated sample was inspected with PDFInfo and rendered with Poppler for visual
review. Physical-phone share-sheet delivery is not covered by mocked tests.

Android and macOS debug builds compile with the export/share integration, and web
startup/hot reload is verified. The current printing plugin does not provide a
macOS Swift Package Manager implementation; Flutter reports a future-migration
warning and uses the project's existing CocoaPods integration. Do not remove that
integration until the sharing plugin supports the selected native build setup.
