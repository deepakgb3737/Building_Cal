# GitHub Publication Checklist

## Attribution

README.md and NOTICE.md state that the implementation used AI assistance while
the calculation formulas, business rules and requirements came from the team.
Third-party authorship and the bundled MIT license remain separate.

## Before Uploading

- Confirm the destination repository and whether it should be public or private.
- Preserve the owner's existing root MIT license from the destination repository.
- Confirm distribution rights for icons, fonts and supplied reference assets.
- Review every staged file for secrets, private project notes and device details.
- Keep pubspec.lock: this is an application, and its dependency resolution should
  be reproducible.
- Keep source, assets, tests, platform configuration, README.md, RULES.md and
  AGENTS.md. Keep packages/easy_floor/LICENSE with the reference package.
- Exclude build output, SDK caches, local.properties, signing credentials,
  environment secrets and local .codex state using the supplied ignore rules.
- Attach APKs to a release if desired rather than committing build directories.

## Verify

```sh
flutter pub get
flutter analyze
flutter test
```

Run verification for the exact revision being published. Historical audit counts
describe earlier revisions, not the current upload. Passing tests do not certify
every device or real-world calculation.

Preparation check on 2026-10-19 (documentation/ignore-rule changes only):

- `flutter test`: 928 passed, 9 skipped.
- `flutter analyze`: 62 existing informational notices, no errors or warnings;
  the default command exits nonzero for these notices.
- README, detailed-notes and publication-guide local links: passed.
- Git upload dry-run: 419 candidate files; no files over 10 MB.
- Targeted private-key/token scan: no matches; not a comprehensive security audit.
- No new physical-device tests, release build, commit or GitHub push performed.

Generated build/cache output is cleaned after verification. Run `flutter pub get`
before the next build. IDE preferences and local platform configuration remain
on disk but are ignored by Git.

## Upload

The owner confirmed the public destination:
https://github.com/deepakgb3737/Building_Cal.
The destination was verified public and empty before the initial upload on
2026-10-19. Publish the prepared project on `main` without a force push.
For later uploads, inspect remote history and preserve existing commits.

## Repository Hygiene

- Commit pubspec.lock, required source/assets, tests and platform projects.
- Exclude generated builds, SDK caches, Pods, ephemeral output, local agent state,
  macOS metadata and private signing material using the supplied ignore rules.
- Keep platform folders and packages/easy_floor; they are not disposable folders.
- Attach APK/AAB/IPA files to a GitHub Release, not the source repository.
- Review historical device screenshots and notes under docs/ for privacy.
- Android release currently uses debug signing. Private production signing is
  not configured by this cleanup.

Inspect the upload contents before committing:

```sh
git status --short
git ls-files --others --exclude-standard
git add --dry-run .
```
