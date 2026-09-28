# Contributing to DeskMate（桌伴）

Thank you for helping improve DeskMate.

## Before opening a change

- Use macOS 14 or later with the current Xcode or Command Line Tools.
- Keep the project dependency-free unless a dependency has a clear maintenance
  and security advantage.
- Read `AGENTS.md`, especially the persistence, drag-and-drop, gesture and
  WeChat transaction invariants.
- Keep unrelated formatting or generated files out of the change.

## Testing

Run:

```sh
./scripts/run-tests.sh
./scripts/build-app.sh
```

Changes to layout, preferences, scanning, gestures or transactions need a
focused regression in the corresponding executable check suite. UI interaction
changes should also include the relevant manual acceptance result in the pull
request description.

Never test by modifying the user's real applications, Dock settings or trackpad
preferences. WeChat companion tests must use temporary fixture bundles.

## Pull requests

Explain:

1. The user-visible problem and intended behavior.
2. The important safety or compatibility trade-offs.
3. Automated tests run.
4. Manual macOS scenarios verified.

DeskMate uses a version-gated private MultitouchSupport fallback. Do not broaden
its operating-system allowlist without verifying the ABI and real hardware on
every added build. Do not describe an observational event path as a supported
way to suppress Mission Control, App Exposé or Spaces.

New contributions to the integrated application are licensed under
GPL-3.0-or-later. The original Launch MIT notice remains in
LICENSES/Launch-MIT.txt. See THIRD_PARTY_NOTICES.md for upstream provenance.
