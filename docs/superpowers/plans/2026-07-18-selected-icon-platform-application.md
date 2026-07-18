# Selected Icon Platform Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine the selected diagonal-recline preview into one final 1024×1024 master and replace the launcher icon files already used by Android, iOS, macOS, and Windows.

**Architecture:** Keep the approved preview as the only image-edit target and allow only small-size readability refinements. Persist one opaque master, derive every platform image deterministically with Lanczos scaling, and extend the existing Dart Windows ICO generator to consume that master. Back up all replaced binaries before mutation and verify dimensions, ICO frames, metadata preservation, and small-size readability afterward.

**Tech Stack:** Built-in image editing, PNG, FFmpeg, Dart, `package:image`, PowerShell, Flutter platform asset catalogs

## Global Constraints

- Use `output/imagegen/snorlax-headphones-composition-v6/02-diagonal-recline.png` as the only edit target.
- Preserve the selected composition, anatomy, palette, semi-flat 2D style, three claws per hand and foot, and restrained cyan-violet headphone glow.
- Create `output/imagegen/snorlax-headphones-final-v7/app-icon-master.png` as an opaque 1024×1024 RGB PNG.
- Back up every replaced icon beneath `output/icon-backups/2026-07-18-before-snorlax-v7/` before replacement.
- Replace only existing Android, iOS, macOS, and Windows icon binaries; do not change manifests or Apple `Contents.json` files.
- Do not add Android adaptive icon layers.
- Keep all earlier preview directories unchanged.
- Do not represent the project-wide Flutter test suite as passing because the Windows loopback listener failure is an accepted environment limitation.

---

### Task 1: Produce the Final Master

**Files:**
- Edit target: `output/imagegen/snorlax-headphones-composition-v6/02-diagonal-recline.png`
- Create: `output/imagegen/snorlax-headphones-final-v7/app-icon-master.png`

**Interfaces:**
- Consumes: the selected 1024×1024 Candidate B preview
- Produces: one opaque 1024×1024 PNG used by every later task

- [ ] **Step 1: Inspect the selected preview**

Open the source at original detail and verify the reclining pose, both belly paws, pointed ears, complete headset, complete feet, and three claw tips on every hand and foot.

- [ ] **Step 2: Run one precise polish edit**

Use the built-in image editor with only the selected preview as `referenced_image_paths`. Request only cleaner 16–64 px silhouette separation, slightly restrained glow, coherent headset edges, and safe padding. Repeat the pose, anatomy, expression, palette, claw counts, and semi-flat 2D finish as invariants; forbid composition changes, head enlargement, new patterns, realistic materials, text, scenery, crop, or extra anatomy.

- [ ] **Step 3: Inspect and persist the accepted output**

Open the generated result at original detail. Copy the accepted generated file to `output/imagegen/snorlax-headphones-final-v7/app-icon-master.png`, then normalize through a sibling temporary file:

```powershell
$dir = 'output/imagegen/snorlax-headphones-final-v7'
$target = Join-Path $dir 'app-icon-master.png'
$temp = Join-Path $dir '_normalized-app-icon-master.png'
ffmpeg -hide_banner -loglevel error -y -i $target -vf 'scale=1024:1024:flags=lanczos,format=rgb24' -frames:v 1 $temp
if ($LASTEXITCODE -ne 0) { throw 'Master normalization failed' }
Move-Item -LiteralPath $temp -Destination $target -Force
```

- [ ] **Step 4: Verify master properties and small-size contact strip**

Read the PNG with `System.Drawing` and require 1024×1024 PNG with pixel format excluding alpha. Generate a 64/32/16 px strip with FFmpeg and inspect that the belly, two feet, face, and headset remain readable.

### Task 2: Make the Windows ICO Generator Source-Driven

**Files:**
- Modify: `tool/generate_windows_icon.dart`
- Create: `tool/verify_windows_icon_generator.dart`

**Interfaces:**
- Produces: `generateWindowsIcon({required String sourcePath, String outputPath})`
- CLI: `dart run tool/generate_windows_icon.dart [sourcePath] [outputPath]`
- ICO frames: 16, 24, 32, 48, and 256 px

- [ ] **Step 1: Write the failing verifier**

Create a standalone Dart verifier that generates a temporary 512×512 PNG, calls `generateWindowsIcon`, decodes the ICO with `img.IcoDecoder`, and requires frame sizes `[16, 24, 32, 48, 256]`.

- [ ] **Step 2: Run it to verify failure**

Run:

```powershell
dart run tool/verify_windows_icon_generator.dart
```

Expected: compilation failure because `generateWindowsIcon` is not yet exported.

- [ ] **Step 3: Implement the minimal generator change**

Replace the procedural wordmark source with `img.decodeImage(File(sourcePath).readAsBytesSync())`, expose `generateWindowsIcon`, retain the existing frame sizes and Lanczos-equivalent average resize, validate the encoded header/frame count, and accept optional source/output CLI arguments. Default the source to the final master and output to the existing Windows icon path.

- [ ] **Step 4: Run verifier and static analysis**

Run:

```powershell
dart run tool/verify_windows_icon_generator.dart
dart analyze tool/generate_windows_icon.dart tool/verify_windows_icon_generator.dart
```

Expected: verifier prints the five sizes and exits zero; analysis reports no issues.

### Task 3: Back Up and Generate Platform Assets

**Files:**
- Create: `output/icon-backups/2026-07-18-before-snorlax-v7/**`
- Modify: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png`
- Modify: `macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png`
- Modify: `windows/runner/resources/app_icon.ico`

**Interfaces:**
- Consumes: the final 1024×1024 master and existing asset-catalog JSON
- Produces: only the binary files already referenced by each platform

- [ ] **Step 1: Copy the current icon binaries into the backup tree**

Preserve their relative paths under `output/icon-backups/2026-07-18-before-snorlax-v7/`. After copying, require that backup file count equals source file count.

- [ ] **Step 2: Generate Android icons**

Use FFmpeg Lanczos resizing from the master for `mdpi=48`, `hdpi=72`, `xhdpi=96`, `xxhdpi=144`, and `xxxhdpi=192`.

- [ ] **Step 3: Generate iOS icons from `Contents.json`**

For every image entry, compute `pixels = round(pointSize × scale)`, resize the master with Lanczos, and overwrite only the named PNG. Require all 18 declared filenames to be generated.

- [ ] **Step 4: Generate macOS icons**

Resize to the size encoded in each existing filename: 16, 32, 64, 128, 256, 512, and 1024 px.

- [ ] **Step 5: Generate the Windows ICO**

Run:

```powershell
dart run tool/generate_windows_icon.dart output/imagegen/snorlax-headphones-final-v7/app-icon-master.png windows/runner/resources/app_icon.ico
```

Expected: five generated frames and exit code zero.

### Task 4: Verify and Commit the Platform Rollout

**Files:**
- Verify: all paths from Task 3
- Preserve: `android/app/src/main/AndroidManifest.xml`
- Preserve: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Preserve: `macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`

**Interfaces:**
- Consumes: generated platform resources
- Produces: evidence that every existing consumer now receives the selected icon without metadata changes

- [ ] **Step 1: Verify platform PNG dimensions**

Read every Android, iOS, and macOS PNG with `System.Drawing`, compare its pixel dimensions to the density map or asset-catalog declaration, and fail on any mismatch.

- [ ] **Step 2: Verify Windows ICO frames**

Run the standalone verifier and parse the committed ICO header/decoder output, requiring exactly `[16, 24, 32, 48, 256]`.

- [ ] **Step 3: Verify preservation and diffs**

Require all earlier preview directories and the backup tree to exist. Use `git diff --name-only` to require that no Android manifest or Apple `Contents.json` changed and that only the intended icon binaries plus the two Windows generator files changed.

- [ ] **Step 4: Run final focused checks**

Run:

```powershell
dart run tool/verify_windows_icon_generator.dart
dart analyze tool/generate_windows_icon.dart tool/verify_windows_icon_generator.dart
git diff --check
```

Expected: all commands exit zero. Do not rerun or claim the environment-blocked project-wide Flutter tests.

- [ ] **Step 5: Commit the rollout**

Stage the intended platform binaries and the two Dart tool files, then commit with:

```powershell
git commit -m "feat: apply selected headphone character app icon"
```
