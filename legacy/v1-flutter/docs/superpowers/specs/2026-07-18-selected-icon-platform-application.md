# Selected Icon Platform Application

## Goal

Promote the user-selected `02-diagonal-recline.png` preview into the application's final launcher icon, preserve its approved composition, and generate the icon files already referenced by the Android, iOS, macOS, and Windows projects.

## Approved Visual Direction

- Use `output/imagegen/snorlax-headphones-composition-v6/02-diagonal-recline.png` as the only edit target.
- Preserve the diagonal recline, stretched feet, modest head, pointed ears, huge warm-cream belly, both paws resting naturally on the belly, closed eyes, and small sleepy open-mouth smile.
- Preserve the semi-flat 2D treatment, low-saturation deep navy/slate body, ivory three-tip claws, warm-brown foot pads, matte dark-indigo headset, narrow cyan-violet rim glow, and deep-navy background.
- Make only small-size app-icon refinements: slightly cleaner silhouette separation, restrained bloom, coherent headset edges, and reliable feature readability at 16–64 px.
- Do not redesign the pose, enlarge the head, add body patterns, add realistic material, or introduce text, scenery, a badge, or a second character.

## Final Master

Create one opaque RGB PNG at:

`output/imagegen/snorlax-headphones-final-v7/app-icon-master.png`

The master must be exactly 1024×1024 and keep all anatomy and headset components inside safe padding. It is the only source used for platform derivatives.

## Platform Derivatives

- Android: replace the existing `mipmap-* / ic_launcher.png` files at 48, 72, 96, 144, and 192 px.
- iOS: replace every PNG named by `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` at its declared point-size multiplied by scale, including the 1024 px marketing icon.
- macOS: replace the existing `app_icon_16.png` through `app_icon_1024.png` files at their filename sizes.
- Windows: update `tool/generate_windows_icon.dart` so it can read the final PNG source, then generate `windows/runner/resources/app_icon.ico` with the project's existing 16, 24, 32, 48, and 256 px frame set.
- Do not add adaptive Android layers or modify platform manifests and asset-catalog metadata.

## Preservation and Recovery

Before replacement, copy the current Android, iOS, macOS, and Windows icon files to:

`output/icon-backups/2026-07-18-before-snorlax-v7/`

Keep all prior generated previews unchanged.

## Verification

- Inspect the final master at full size and at true 64, 32, and 16 px.
- Verify the master is opaque 1024×1024 PNG.
- Verify every generated PNG has the pixel dimensions implied by its platform resource name or asset catalog.
- Verify the Windows ICO contains exactly five frames with sizes 16, 24, 32, 48, and 256.
- Confirm no Android manifest or Apple asset-catalog JSON file changed.
- Run the focused Windows icon-generator test and static analysis for the edited generator.
- Project-wide Flutter tests remain a separate known environment limitation because the local test listener cannot bind/connect through `127.0.0.1`; do not represent them as passing.

## Out of Scope

- Store-listing screenshots or marketing artwork.
- Android adaptive icon foreground/background layers.
- Reworking application UI or branding text.
- Changing the selected composition after platform generation.
