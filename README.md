# BuildCalc

A Flutter application for building-material estimates, ceiling planning,
floor-plan drawing and everyday site calculations. Designed for mobile, with
Android, macOS and web platform folders included.

## Calculators And Tools

| Tool | What it does |
| --- | --- |
| Grid Ceiling | Calculates rectangular-room grid placement, tile purchases, T sections and wall angles; shows material estimates and 2D/3D layouts. |
| PVC Ceiling | Plans PVC panels for rectangular and supported irregular rooms, prioritizing fewer joints before stock savings, with cutting quantities and layout previews. |
| EasyFloor | Draws and edits connected floor-plan walls with dimensions, presets, notes, snapping, tape measurement and proposed dashed walls. Supports local drawing documents. |
| Unit Converter | Converts lengths between supported metric and imperial units, updating all units together. |
| Area Converter | Converts square measurements between supported metric and imperial units. |
| Calculator | Arithmetic with parentheses, percentages, extra operations and session history. Long-press a result to copy it. |
| Compass | Sensor-based heading and cardinal directions on supported hardware. |
| Drawer Calculator | Equal, one-custom or multiple-custom drawer heights, accounting for clearances and gaps. Includes a 2D preview. |
| Paint | Estimates litres and whole containers using area, coverage, coats and allowance. |
| Flooring Tiles | Estimates tile and box quantities from area, tile size, pack size and allowance. |
| Concrete Volume | Calculates rectangular concrete volume with an optional allowance. |
| Plaster | Estimates material and bags using area, thickness and product consumption. |

These 12 tools are available from Home. Area Calculator source is retained but
not linked from Home. L-shaped **Grid Ceiling** is disabled in normal builds;
its code is retained. EasyFloor and PVC shape support are separate features.

## Run Locally

Use a Flutter SDK supporting the locked dependencies: Dart 3.13 or newer and
Flutter 3.44 or newer for the Android configuration. Android uses Gradle 9.1.0,
AGP 9.0.1 and Kotlin 2.3.20; use JDK 17 or newer. macOS requires macOS 12 or
newer, Xcode and CocoaPods.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

Use `flutter run -d macos` for desktop or `flutter run -d chrome` for a browser.
Compass availability depends on the platform and sensors.

## Check And Build

```sh
flutter analyze
flutter test
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`.
Android release currently uses **debug signing** for testing. Configure private
release signing before store distribution; never commit keys.
See the [publication checklist](docs/GITHUB_PUBLICATION.md) before uploading.

## Project Structure

```text
lib/
  main.dart             App entry point
  core/                 Shared validation and central Material theme
  ui/                   Shared colors, typography, styles and widgets
  features/
    <tool>/logic/       Calculation engines, models and services
    <tool>/ui/          Screens, painters and interaction widgets
assets/                 Icons and supplied theme reference files
test/                   Unit and widget tests
integration_test/       Device workflow tests
packages/easy_floor/    Bundled reference package and its licence
docs/                   Feature guides, assumptions and historical audits
android/ macos/ web/    Platform projects
```

Calculations run locally in Dart engines/services; there is no remote backend.
Shared visuals live in `lib/ui/` and `lib/core/theme/`. Local layout and some
legacy effects remain feature-specific; styling is not fully centralized.
Read [RULES.md](RULES.md) and [AGENTS.md](AGENTS.md) before editing.

## Important Limits

- Material quantities are planning estimates, not structural designs or installation certification. Check product specifications and site conditions before ordering or installing.
- Grid Ceiling uses a nominal 600 mm grid, 595 mm tiles and 3048 mm main-runner stock (10 ft). Offcut packing gives a feasible purchase estimate, not a proven global minimum. Perimeter T substitutions require compatible hardware.
- Hanger quantity currently uses a perimeter estimate, not an engineered hanger-position plan. The requested hanger-spacing update is not implemented.
- Product-dependent estimates require suitable user-supplied rates. Allowances are editable estimates, not universal specifications.
- Calculator arithmetic uses floating-point numbers. Percent is divide-by-100, not a contextual percentage increase. History lasts only for the current screen session.
- Automated tests do not verify every phone, keyboard, sensor or installation condition. Historical audits describe their own tested revisions, not guarantees for the current build.

## Documentation

- [Detailed project and feature notes](docs/PROJECT_DETAILS.md)
- [PVC Ceiling](docs/PVC_CEILING.md)
- [Material formulas and assumptions](docs/MATERIAL_CALCULATORS.md)
- [EasyFloor drawing engine](docs/EASYFLOOR_DRAWING.md)
- [EasyFloor documents](docs/EASYFLOOR_DOCUMENTS.md)
- [Disabled Grid Ceiling L-shape](docs/GRID_CEILING_L_SHAPE_DISABLED.md)

## Credit And Licence

Built for BuildCalc by **inusltebuilding.com, Sirsi, Uttara Kannada**.

The application was built using **AI-assisted development** under the team's
direction. The calculation formulas, business rules, requirements and domain
decisions were supplied by our team, not invented by AI. Standard mathematical
and unit definitions are not claimed as original inventions.

Licensed under the [MIT License](LICENSE). Third-party code and assets retain
their own authorship and licences. See [NOTICE.md](NOTICE.md); review supplied
asset distribution rights before publishing publicly.
