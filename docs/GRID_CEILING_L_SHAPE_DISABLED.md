# Grid Ceiling L-shape: Disabled

Status: **Disabled in normal builds**, at the user's request.

The Grid Ceiling calculator is rectangle-only in the shipped/default UI. The
Rectangle / L-shape chooser, missing-corner selector, arm fields, preview,
focus highlights and L-shaped results are hidden. No L-shaped calculation can
be selected through the normal UI. Existing rectangle behavior is preserved.

## Code is retained

- `lib/features/grid_ceiling/logic/l_shape/`: backend, validation and result model.
- `lib/features/grid_ceiling/ui/l_shape/`: inputs, preview and 2D/3D result views.
- `test/features/grid_ceiling/l_shape/`: backend, UI and disabled-state tests.
- Integration remains in `lib/features/grid_ceiling/ui/grid_ceiling_screen.dart`.

Nothing was deleted. The rectangular engine is independent of this backend.

## How it is disabled

`GridCeilingCalculatorScreen.lShapeEnabled` reads the compile-time boolean
`BUILDCALC_ENABLE_L_SHAPE`, which defaults to `false`. The selector, selected
shape state, calculation routing and L-shape result display honor this gate.
There is no in-app setting to turn it on. Use a restart/rebuild when changing
compile-time defines; hot reload alone is not a release configuration change.

## Re-enable for development

Only when L-shape support is wanted again:

```sh
flutter run --dart-define=BUILDCALC_ENABLE_L_SHAPE=true
```

Default/release builds should omit that define or explicitly set it to false.

## Regression checks

```sh
flutter test
flutter test --dart-define=BUILDCALC_ENABLE_L_SHAPE=true test/features/grid_ceiling/l_shape
```

Backend and projection tests run in both configurations. L-shaped form/focus
checks run in the opt-in configuration; the default-hidden-state test runs in
normal builds. This prevents disabling the UI from deleting its test coverage.

The backend README documents its purchase-estimate and installation assumptions.
Enabling the flag does not remove those limits or constitute structural approval.
