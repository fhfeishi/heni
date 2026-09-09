# Three-Composition App Icon Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce three consistent 1024×1024 semi-flat 2D app-icon previews covering centered sitting, diagonal reclining, and side-leaning compositions without replacing any platform launcher asset.

**Architecture:** Use the accepted AI-generated v5 single-paw image as the only direct image-edit/style anchor. Generate and accept each composition sequentially, correct only one visual defect per follow-up edit, then normalize the three accepted PNGs and present them in a lightweight inline comparison.

**Tech Stack:** Built-in image generation and editing, PNG, FFmpeg, PowerShell with `System.Drawing`, HTML/CSS/JavaScript, Codex inline visualization renderer

## Global Constraints

- Create exactly three new 1024×1024 PNG files under `output/imagegen/snorlax-headphones-composition-v6/`.
- Preserve every existing v3, v4, v5, full-body, small-head, and other preview asset.
- Use `output/imagegen/snorlax-headphones-2d-v5/02-cel-one-paw-headphone.png` as the only direct edit/style image input.
- Do not send `stage2.jpg` or `stage3.jpg` to image generation; translate their reclining pose ideas into text.
- Use a clean semi-flat 2D illustration style with low-saturation deep navy/slate body color, warm yellow-cream face and belly, ivory claws, warm-brown sole pads, darker navy outlines, and only broad soft same-hue modeling.
- Keep the head modest in size, the belly dominant, both pointed ears readable, and every hand and foot complete with exactly three visible claw tips.
- Use medium matte dark-indigo oval over-ear cups, natural near/far perspective, one coherent headband behind the ears, and one narrow restrained cyan-to-violet rim glow.
- Use a clean deep-navy background with a restrained soft radial halo; no scenery, text, logo, watermark, secondary character, stripes, spots, whiskers, realistic fur, plush fibers, clay, plastic, hard highlights, or aggressive neon bloom.
- Keep all anatomy and headset parts inside generous app-icon-safe padding and readable at 64×64.
- Do not modify Windows, Android, iOS, or macOS launcher resources during this plan.
- Keep generated preview binaries uncommitted until the user selects a final icon; commit only specification and plan documents.

## File Map

- Direct edit/style base: `output/imagegen/snorlax-headphones-2d-v5/02-cel-one-paw-headphone.png`
- Create: `output/imagegen/snorlax-headphones-composition-v6/01-centered-tilted-sit.png`
- Create: `output/imagegen/snorlax-headphones-composition-v6/02-diagonal-recline.png`
- Create: `output/imagegen/snorlax-headphones-composition-v6/03-side-lean-half-recline.png`
- Create: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-composition-v6-compare.html`
- Create: three 400×400 JPEG comparison thumbnails beside the visualization fragment
- Create: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-composition-v6-64px-contact.png`

---

### Task 1: Build Candidate A — Centered Tilted Sit

**Files:**
- Base: `output/imagegen/snorlax-headphones-2d-v5/02-cel-one-paw-headphone.png`
- Create: `output/imagegen/snorlax-headphones-composition-v6/01-centered-tilted-sit.png`

**Interfaces:**
- Consumes: the accepted v5 single-paw 2D PNG
- Produces: the polished Candidate A PNG and the shared visual anchor for comparison review

- [ ] **Step 1: Verify the edit base before generation**

Run:

```powershell
Add-Type -AssemblyName System.Drawing
$path = 'output/imagegen/snorlax-headphones-2d-v5/02-cel-one-paw-headphone.png'
$image = [System.Drawing.Image]::FromFile((Resolve-Path $path))
try {
  [pscustomobject]@{
    Width = $image.Width
    Height = $image.Height
    Format = $image.RawFormat.Guid
  }
} finally {
  $image.Dispose()
}
```

Expected: `1024`, `1024`, and PNG format GUID `b96b3caf-0728-11d3-9d7b-0000f81ef32e`.

- [ ] **Step 2: Generate the app-icon polish edit**

Use the built-in image editing tool with the base PNG as `referenced_image_paths` and this exact prompt:

```text
Use case: precise-object-edit
Asset type: 1024×1024 app-icon preview
Primary request: Polish this supplied original AI-generated semi-flat 2D icon for small-size app-icon readability while preserving the approved centered seated composition.
Subject: A cute sleepy large-bellied navy-and-cream creature wearing glowing over-ear headphones, full body visible.
Style/medium: clean semi-flat 2D illustration, broad solid color fields, darker navy outlines, only very soft same-hue volume shading.
Composition/framing: torso upright and front-facing; complete head, pointed ears, headset, arms, huge belly, legs, round feet, pads, and claws inside generous safe padding; complete head/face/ears/headset tilted 10–12 degrees toward image right; head remains modest in size; large belly stays central; both feet form a stable nearly symmetrical base.
Pose: image-right paw lightly touches the lower outside rim of the near ear cup without covering the ear or glow; image-left paw rests naturally on the upper belly following its curve.
Expression: closed eyes and a quiet small content smile.
Color palette: low-saturation deep navy/slate body, warm yellow-cream face and belly, ivory claws, warm-brown sole pads, matte dark-indigo ear cups, narrow cyan-to-violet rim glow, deep-navy background with a restrained soft halo.
Constraints: preserve exactly three visible ivory claw tips on each hand and exactly three on each foot; keep both pointed ears readable; keep one coherent diagonal headband behind the ears and natural near/far oval ear-cup perspective; reduce glare and overly broad bloom; preserve clean no-pattern surfaces.
Avoid: head enlargement, anatomy changes, extra or missing limbs, malformed paws, duplicate cups, broken band, stripes, spots, whiskers, realistic fur, plush fibers, clay, plastic, hard highlights, aggressive neon, scenery, text, logo, watermark, crop.
```

Expected: one polished Candidate A image with the original character identity and pose intact.

- [ ] **Step 3: Inspect Candidate A at full size**

Open the generated image with `view_image` at original detail. Reject the image if any of these are false:

- the full head unit visibly tilts 10°–12° while the torso remains upright;
- the image-right paw touches only the near ear-cup rim and the other paw rests on the belly;
- each hand and foot shows exactly three claws;
- the ear cups are oval, the headband is continuous, and both pointed ears remain visible;
- all anatomy is inside safe padding and the glow does not overpower the silhouette.

- [ ] **Step 4: Correct at most one localized defect per edit**

If Candidate A has one isolated defect, run one precise edit naming only that defect and repeat every invariant from Step 2. Examples of single-defect requests are:

```text
Change only the image-left hand: restore exactly three small ivory claw tips in a natural relaxed fan. Preserve every other pixel-level design decision, pose, palette, headset part, head tilt, background, and safe padding.
```

```text
Change only the headset band: make it one continuous medium-thin dark-indigo band behind both pointed ears, with one narrow cyan-to-violet rim glow. Preserve the complete character, anatomy, claw counts, pose, palette, and background unchanged.
```

Do not combine anatomy, palette, headset, and composition changes in one correction.

- [ ] **Step 5: Persist and normalize Candidate A**

Copy the accepted built-in output from its exact returned generated-image path to `output/imagegen/snorlax-headphones-composition-v6/01-centered-tilted-sit.png`. Then normalize through a sibling temporary file:

```powershell
$dir = 'output/imagegen/snorlax-headphones-composition-v6'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$target = Join-Path $dir '01-centered-tilted-sit.png'
$temp = Join-Path $dir '_normalized-01-centered-tilted-sit.png'
ffmpeg -hide_banner -loglevel error -y -i $target -vf 'scale=1024:1024:flags=lanczos' -frames:v 1 $temp
if ($LASTEXITCODE -ne 0) { throw 'Candidate A normalization failed' }
Move-Item -LiteralPath $temp -Destination $target -Force
```

- [ ] **Step 6: Verify Candidate A file properties**

Run:

```powershell
Add-Type -AssemblyName System.Drawing
$path = 'output/imagegen/snorlax-headphones-composition-v6/01-centered-tilted-sit.png'
$image = [System.Drawing.Image]::FromFile((Resolve-Path $path))
try {
  if ($image.Width -ne 1024 -or $image.Height -ne 1024) {
    throw "Wrong Candidate A dimensions: $($image.Width)x$($image.Height)"
  }
  if ($image.RawFormat.Guid -ne [Guid]'b96b3caf-0728-11d3-9d7b-0000f81ef32e') {
    throw 'Candidate A is not PNG'
  }
  [pscustomobject]@{ Width = $image.Width; Height = $image.Height; Format = 'PNG' }
} finally {
  $image.Dispose()
}
```

Expected: one 1024×1024 PNG at the exact target path.

---

### Task 2: Build Candidate B — Diagonal Recline

**Files:**
- Base: `output/imagegen/snorlax-headphones-2d-v5/02-cel-one-paw-headphone.png`
- Create: `output/imagegen/snorlax-headphones-composition-v6/02-diagonal-recline.png`

**Interfaces:**
- Consumes: the accepted v5 2D character as the only direct visual anchor and Candidate A's approved palette/finish as a review reference
- Produces: the diagonal reclining Candidate B PNG

- [ ] **Step 1: Generate Candidate B with a textual pose transformation**

Use the built-in image editing tool with only the v5 base PNG in `referenced_image_paths` and this exact prompt:

```text
Use case: precise-object-edit
Asset type: 1024×1024 app-icon preview
Primary request: Recompose this supplied original AI-generated character into an original diagonal reclining pose while preserving the character design, clean semi-flat 2D art direction, palette, pointed ears, huge belly, round paws, foot pads, and wearable headphones.
Subject: The same cute sleepy large-bellied navy-and-cream creature, now comfortably reclining and stretching its legs.
Style/medium: clean semi-flat 2D illustration with broad solid color fields, darker navy outlines, and only very soft broad same-hue volume shading; no plush texture.
Composition/framing: recline the body along a 16–20 degree diagonal across the square; keep the huge belly dominant; place one complete foot moderately closer to the viewer and subtly larger, with the second complete foot slightly farther back; avoid fisheye distortion; keep all anatomy and headset parts inside generous safe padding.
Pose: both round paws rest naturally on the belly with wrists and forearms following the reclining body rather than forming a rigid mirror pose; the tilted head settles toward the lower ear cup as if comfortably listening.
Expression: closed eyes and a small open-mouth yawn or sleepy laugh; inner mouth is restrained warm coral and must remain cute rather than loud.
Headphones: medium matte dark-indigo oval cups with natural high/low and near/far perspective, one coherent band behind both pointed ears, and one narrow cyan-to-violet rim glow.
Color palette: low-saturation deep navy/slate body, warm yellow-cream face and belly, ivory claws, warm-brown sole pads, deep-navy background with a restrained soft halo.
Constraints: exactly three visible ivory claw tips on each hand and exactly three on each foot; both pointed ears visible; full head, body, hands, legs, and feet remain readable; clean no-pattern surfaces.
Avoid: copying an animation frame, tree or forest scenery, exaggerated perspective, giant foreground foot, cropped limb, stiff symmetric arms, head enlargement, extra or missing limbs, malformed paws, duplicate cups, broken band, stripes, spots, whiskers, fur, plush, clay, plastic, hard highlights, aggressive neon, text, logo, watermark.
```

Expected: one original diagonal reclining image that belongs to the same set as Candidate A.

- [ ] **Step 2: Inspect Candidate B at full size**

Open the generated image with `view_image` at original detail. Accept only if:

- the body clearly reclines 16°–20° and is not merely a rotated head;
- one foot is moderately closer while both full feet and all toe claws remain visible;
- both paws rest naturally on the belly with exactly three claws each;
- the closed-eye open-mouth sleepy expression reads softly;
- the headset follows the reclining head and remains one coherent object;
- the image stays clean, semi-flat, and free of copied scenery.

- [ ] **Step 3: Correct one localized defect if needed**

If Candidate B has one isolated defect, run one precise edit naming only that defect and restating the reclining pose, both belly paws, exact claw counts, headset continuity, palette, style, background, and crop as invariants. Do not combine anatomy, palette, headset, and composition changes in one correction. For a foot-perspective defect, use:

```text
Change only the two feet: keep one foot moderately closer and subtly larger, keep the other slightly farther back, show both complete warm-brown sole pads, and restore exactly three ivory toe claws on each foot. Preserve the entire reclining body, both belly paws, expression, headset, palette, style, background, and crop unchanged.
```

- [ ] **Step 4: Persist and normalize Candidate B**

Copy the accepted built-in output from its exact returned generated-image path to `output/imagegen/snorlax-headphones-composition-v6/02-diagonal-recline.png`. Then run:

```powershell
$dir = 'output/imagegen/snorlax-headphones-composition-v6'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$target = Join-Path $dir '02-diagonal-recline.png'
$temp = Join-Path $dir '_normalized-02-diagonal-recline.png'
ffmpeg -hide_banner -loglevel error -y -i $target -vf 'scale=1024:1024:flags=lanczos' -frames:v 1 $temp
if ($LASTEXITCODE -ne 0) { throw 'Candidate B normalization failed' }
Move-Item -LiteralPath $temp -Destination $target -Force
```

- [ ] **Step 5: Verify Candidate B file properties**

Run:

```powershell
Add-Type -AssemblyName System.Drawing
$path = 'output/imagegen/snorlax-headphones-composition-v6/02-diagonal-recline.png'
$image = [System.Drawing.Image]::FromFile((Resolve-Path $path))
try {
  if ($image.Width -ne 1024 -or $image.Height -ne 1024) {
    throw "Wrong Candidate B dimensions: $($image.Width)x$($image.Height)"
  }
  if ($image.RawFormat.Guid -ne [Guid]'b96b3caf-0728-11d3-9d7b-0000f81ef32e') {
    throw 'Candidate B is not PNG'
  }
  [pscustomobject]@{ Width = $image.Width; Height = $image.Height; Format = 'PNG' }
} finally {
  $image.Dispose()
}
```

Expected: one 1024×1024 PNG at the exact target path.

---

### Task 3: Build Candidate C — Side-Leaning Half Recline

**Files:**
- Base: `output/imagegen/snorlax-headphones-2d-v5/02-cel-one-paw-headphone.png`
- Create: `output/imagegen/snorlax-headphones-composition-v6/03-side-lean-half-recline.png`

**Interfaces:**
- Consumes: the accepted v5 2D character as the only direct visual anchor and the approved finish of Candidates A and B as review references
- Produces: the side-leaning Candidate C PNG

- [ ] **Step 1: Generate Candidate C with an asymmetric half-recline**

Use the built-in image editing tool with only the v5 base PNG in `referenced_image_paths` and this exact prompt:

```text
Use case: precise-object-edit
Asset type: 1024×1024 app-icon preview
Primary request: Recompose this supplied original AI-generated character into an original side-leaning half-reclined pose while preserving the character design and the clean semi-flat 2D visual language.
Subject: The same cute sleepy large-bellied navy-and-cream creature, relaxed between an upright sit and a full recline.
Style/medium: clean semi-flat 2D illustration with broad solid color fields, darker navy outlines, and only a small amount of soft broad same-hue volume shading.
Composition/framing: body gently leans toward image right; complete head/face/ears/headset tilt 12–15 degrees toward image right; one complete leg extends toward the foreground while the other naturally bends or recedes; keep both feet, sole pads, hands, pointed ears, and all headset parts inside generous app-icon-safe padding; keep the head modest and the huge belly dominant.
Pose: image-right arm is soft and draped, with its round paw resting loosely on the outer edge of the near ear cup without gripping or hiding the pointed ear; image-left paw rests lower on the belly arc than in the centered candidate.
Expression: closed eyes and a slightly broader satisfied smile than the centered candidate.
Headphones: medium matte dark-indigo oval cups with natural near/far perspective, one coherent diagonal band behind both pointed ears, and one narrow restrained cyan-to-violet rim glow.
Color palette: low-saturation deep navy/slate body, warm yellow-cream face and belly, ivory claws, warm-brown sole pads, deep-navy background with a restrained soft halo.
Constraints: exactly three visible ivory claw tips on each hand and exactly three on each foot; clean no-pattern surfaces; complete readable anatomy; balanced asymmetry without looking unstable.
Avoid: full upright symmetry, full horizontal recline, stiff raised arm, gripping the ear cup, hiding an ear, exaggerated foreground foot, crop, head enlargement, extra or missing limbs, malformed paws, duplicate cups, broken band, stripes, spots, whiskers, fur, plush, clay, plastic, hard highlights, aggressive neon, scenery, text, logo, watermark.
```

Expected: one playful but calm side-leaning image that remains legible as an app icon.

- [ ] **Step 2: Inspect Candidate C at full size**

Open the generated image with `view_image` at original detail. Accept only if:

- the body reads as a half-recline rather than Candidate A or Candidate B repeated;
- one leg extends and the other recedes naturally, with both full feet visible;
- the image-right paw drapes loosely on the near ear-cup edge and the other paw sits lower on the belly;
- every hand and foot has exactly three claws;
- both pointed ears and the continuous headset band remain readable;
- the satisfied closed-eye expression is distinct from Candidate A without becoming exaggerated.

- [ ] **Step 3: Correct one localized defect if needed**

If Candidate C has one isolated defect, run one precise edit naming only that defect and restating the half-recline, asymmetric leg positions, one draped ear-cup paw, one low belly paw, exact claw counts, headset continuity, palette, style, background, and crop as invariants. Do not combine anatomy, palette, headset, and composition changes in one correction. For an overly stiff raised arm, use:

```text
Change only the image-right arm and hand: make the arm hang in a soft relaxed curve and let the round paw rest loosely on the outside edge of the near ear cup, below the pointed ear, with exactly three visible ivory claws. Preserve the complete side-leaning body, other paw, legs, feet, head tilt, expression, headset, palette, style, background, and crop unchanged.
```

- [ ] **Step 4: Persist and normalize Candidate C**

Copy the accepted built-in output from its exact returned generated-image path to `output/imagegen/snorlax-headphones-composition-v6/03-side-lean-half-recline.png`. Then run:

```powershell
$dir = 'output/imagegen/snorlax-headphones-composition-v6'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$target = Join-Path $dir '03-side-lean-half-recline.png'
$temp = Join-Path $dir '_normalized-03-side-lean-half-recline.png'
ffmpeg -hide_banner -loglevel error -y -i $target -vf 'scale=1024:1024:flags=lanczos' -frames:v 1 $temp
if ($LASTEXITCODE -ne 0) { throw 'Candidate C normalization failed' }
Move-Item -LiteralPath $temp -Destination $target -Force
```

- [ ] **Step 5: Verify Candidate C file properties**

Run:

```powershell
Add-Type -AssemblyName System.Drawing
$path = 'output/imagegen/snorlax-headphones-composition-v6/03-side-lean-half-recline.png'
$image = [System.Drawing.Image]::FromFile((Resolve-Path $path))
try {
  if ($image.Width -ne 1024 -or $image.Height -ne 1024) {
    throw "Wrong Candidate C dimensions: $($image.Width)x$($image.Height)"
  }
  if ($image.RawFormat.Guid -ne [Guid]'b96b3caf-0728-11d3-9d7b-0000f81ef32e') {
    throw 'Candidate C is not PNG'
  }
  [pscustomobject]@{ Width = $image.Width; Height = $image.Height; Format = 'PNG' }
} finally {
  $image.Dispose()
}
```

Expected: one 1024×1024 PNG at the exact target path.

---

### Task 4: Validate the Set and Present a Three-Choice Comparison

**Files:**
- Verify: `output/imagegen/snorlax-headphones-composition-v6/*.png`
- Create: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-composition-v6-compare.html`
- Create: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-composition-v6-01.jpg`
- Create: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-composition-v6-02.jpg`
- Create: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-composition-v6-03.jpg`

**Interfaces:**
- Consumes: the three accepted and normalized candidate PNGs
- Produces: a verified three-file set and an interactive inline comparison

- [ ] **Step 1: Verify the complete PNG set**

Run:

```powershell
$ErrorActionPreference = 'Stop'
$dir = 'output/imagegen/snorlax-headphones-composition-v6'
$expectedGuid = [Guid]'b96b3caf-0728-11d3-9d7b-0000f81ef32e'
Add-Type -AssemblyName System.Drawing
$files = Get-ChildItem -LiteralPath $dir -File -Filter '*.png' | Sort-Object Name
if ($files.Count -ne 3) { throw "Expected 3 PNGs, found $($files.Count)" }
$report = foreach ($file in $files) {
  $image = [System.Drawing.Image]::FromFile($file.FullName)
  try {
    if ($image.Width -ne 1024 -or $image.Height -ne 1024) {
      throw "Wrong dimensions: $($file.Name) $($image.Width)x$($image.Height)"
    }
    if ($image.RawFormat.Guid -ne $expectedGuid) {
      throw "Wrong format: $($file.Name)"
    }
    [pscustomobject]@{ Name = $file.Name; Size = '1024x1024'; Format = 'PNG'; Bytes = $file.Length }
  } finally {
    $image.Dispose()
  }
}
$report | Format-Table -AutoSize
```

Expected: exactly the three approved filenames, all `1024x1024` and `PNG`.

- [ ] **Step 2: Perform a 64×64 readability review**

Create one contact strip that renders each source at a true 64×64 before stacking:

```powershell
$dir = 'output/imagegen/snorlax-headphones-composition-v6'
$viz = 'C:\Users\10354\.codex\visualizations\2026\07\18\019f7344-f45e-7130-8e71-2d4eb0cc2790'
$contact = Join-Path $viz 'snorlax-composition-v6-64px-contact.png'
ffmpeg -hide_banner -loglevel error -y `
  -i (Join-Path $dir '01-centered-tilted-sit.png') `
  -i (Join-Path $dir '02-diagonal-recline.png') `
  -i (Join-Path $dir '03-side-lean-half-recline.png') `
  -filter_complex '[0:v]scale=64:64:flags=lanczos[a];[1:v]scale=64:64:flags=lanczos[b];[2:v]scale=64:64:flags=lanczos[c];[a][b][c]hstack=inputs=3[out]' `
  -map '[out]' -frames:v 1 $contact
if ($LASTEXITCODE -ne 0) { throw '64px contact strip render failed' }
```

Open the contact strip with `view_image` at original detail. Confirm that the head tilt, large belly, two foot pads, and headset silhouette remain recognizable and that the glow does not merge into a bright ring.

- [ ] **Step 3: Create compact 400×400 comparison JPEGs**

Run:

```powershell
$src = 'output/imagegen/snorlax-headphones-composition-v6'
$viz = 'C:\Users\10354\.codex\visualizations\2026\07\18\019f7344-f45e-7130-8e71-2d4eb0cc2790'
$map = @{
  '01-centered-tilted-sit.png' = 'snorlax-composition-v6-01.jpg'
  '02-diagonal-recline.png' = 'snorlax-composition-v6-02.jpg'
  '03-side-lean-half-recline.png' = 'snorlax-composition-v6-03.jpg'
}
foreach ($name in $map.Keys) {
  ffmpeg -hide_banner -loglevel error -y -i (Join-Path $src $name) -vf 'scale=400:400:flags=lanczos' -q:v 5 (Join-Path $viz $map[$name])
  if ($LASTEXITCODE -ne 0) { throw "Comparison thumbnail failed: $name" }
}
```

Expected: three compact JPEGs, each 400×400.

- [ ] **Step 4: Create the inline comparison fragment**

Use `apply_patch` to create the visualization file with this exact fragment:

```html
<div id="snorlax-composition-v6-compare">
  <style>
    #snorlax-composition-v6-compare {
      width: 100%;
      color: var(--foreground);
    }

    #snorlax-composition-v6-compare .icon-choice {
      margin: 0;
      min-width: 0;
    }

    #snorlax-composition-v6-compare .preview-label {
      display: block;
      cursor: pointer;
    }

    #snorlax-composition-v6-compare .icon-preview {
      display: block;
      width: 100%;
      aspect-ratio: 1;
      object-fit: cover;
      border-radius: 12px;
    }

    #snorlax-composition-v6-compare .option-copy {
      margin-top: 0.5rem;
    }

    #snorlax-composition-v6-compare .choice-actions {
      margin-top: 1rem;
    }

    #snorlax-composition-v6-compare [data-selection-status] {
      flex: 1 1 16rem;
      margin: 0;
    }
  </style>

  <div class="viz-grid" role="radiogroup" aria-label="选择最终图标构图方向">
    <figure class="icon-choice">
      <label class="preview-label" for="composition-v6-01">
        <img class="icon-preview" src="data:image/jpeg;base64,__IMG01__" alt="正坐歪头，单爪轻扶耳机">
      </label>
      <figcaption class="option-copy">
        <div class="form-check">
          <input class="form-check-input" type="radio" name="composition-v6" id="composition-v6-01" value="01" data-label="正坐歪头 · 单爪扶耳机">
          <label class="form-check-label" for="composition-v6-01">01 正坐歪头 · 单爪扶耳机</label>
        </div>
      </figcaption>
    </figure>

    <figure class="icon-choice">
      <label class="preview-label" for="composition-v6-02">
        <img class="icon-preview" src="data:image/jpeg;base64,__IMG02__" alt="斜躺伸腿，双爪自然放肚皮">
      </label>
      <figcaption class="option-copy">
        <div class="form-check">
          <input class="form-check-input" type="radio" name="composition-v6" id="composition-v6-02" value="02" data-label="斜躺伸腿 · 双爪放肚皮">
          <label class="form-check-label" for="composition-v6-02">02 斜躺伸腿 · 双爪放肚皮</label>
        </div>
      </figcaption>
    </figure>

    <figure class="icon-choice">
      <label class="preview-label" for="composition-v6-03">
        <img class="icon-preview" src="data:image/jpeg;base64,__IMG03__" alt="侧靠半躺，单爪松搭耳罩">
      </label>
      <figcaption class="option-copy">
        <div class="form-check">
          <input class="form-check-input" type="radio" name="composition-v6" id="composition-v6-03" value="03" data-label="侧靠半躺 · 松搭耳罩">
          <label class="form-check-label" for="composition-v6-03">03 侧靠半躺 · 松搭耳罩</label>
        </div>
      </figcaption>
    </figure>
  </div>

  <div class="viz-controls choice-actions">
    <p class="text-small" data-selection-status aria-live="polite"></p>
    <button class="btn btn-primary" type="button" data-confirm>选这个方向制作最终图标</button>
  </div>

  <script>
    (() => {
      const root = document.getElementById('snorlax-composition-v6-compare');
      if (!root) return;

      const radios = Array.from(root.querySelectorAll('input[name="composition-v6"]'));
      const status = root.querySelector('[data-selection-status]');
      const confirmButton = root.querySelector('[data-confirm]');

      const getSelected = () => radios.find((radio) => radio.checked);
      const updateSelection = () => {
        const selected = getSelected();
        status.textContent = selected
          ? `当前选择：${selected.value} ${selected.dataset.label}`
          : '请选择一个构图方向';
      };

      radios.forEach((radio) => radio.addEventListener('change', updateSelection));

      confirmButton.addEventListener('click', async () => {
        const selected = getSelected();
        if (!selected) {
          status.textContent = '请先选择一个构图方向';
          return;
        }

        confirmButton.disabled = true;
        try {
          if (window.openai && typeof window.openai.sendFollowUpMessage === 'function') {
            await window.openai.sendFollowUpMessage({
              title: '确认最终图标方向',
              prompt: `我选择 ${selected.value} ${selected.dataset.label}。请以这张预览继续制作最终应用图标并生成各平台资源。`
            });
            status.textContent = `已提交：${selected.value} ${selected.dataset.label}`;
          } else {
            status.textContent = `已选择：${selected.value} ${selected.dataset.label}。请直接把编号告诉我。`;
          }
        } catch (error) {
          status.textContent = `已选择：${selected.value} ${selected.dataset.label}。提交未完成，请直接把编号告诉我。`;
        } finally {
          confirmButton.disabled = false;
        }
      });

      updateSelection();
    })();
  </script>
</div>
```

After `apply_patch`, inject the JPEG data using a mechanical replacement:

```powershell
$viz = 'C:\Users\10354\.codex\visualizations\2026\07\18\019f7344-f45e-7130-8e71-2d4eb0cc2790'
$htmlPath = Join-Path $viz 'snorlax-composition-v6-compare.html'
$html = [IO.File]::ReadAllText($htmlPath)
1..3 | ForEach-Object {
  $index = $_.ToString('00')
  $token = '__IMG' + $index + '__'
  $jpg = Join-Path $viz "snorlax-composition-v6-$index.jpg"
  $base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jpg))
  $html = $html.Replace($token, $base64)
}
[IO.File]::WriteAllText($htmlPath, $html, [Text.UTF8Encoding]::new($false))
```

The fragment contains no document wrapper, network request, external resource, or application-code change.

- [ ] **Step 5: Validate the comparison fragment**

Run:

```powershell
$path = 'C:\Users\10354\.codex\visualizations\2026\07\18\019f7344-f45e-7130-8e71-2d4eb0cc2790\snorlax-composition-v6-compare.html'
$html = [IO.File]::ReadAllText($path)
$bytes = (Get-Item -LiteralPath $path).Length
$jpegCount = ([regex]::Matches($html, 'data:image/jpeg;base64,')).Count
$radioCount = ([regex]::Matches($html, 'type="radio"\s+name="composition-v6"')).Count
$primaryCount = ([regex]::Matches($html, 'class="btn btn-primary"')).Count
if ($bytes -ge 2MB) { throw "Fragment too large: $bytes" }
if ($jpegCount -ne 3) { throw "Expected 3 embedded JPEGs, found $jpegCount" }
if ($radioCount -ne 3) { throw "Expected 3 radio inputs, found $radioCount" }
if ($primaryCount -ne 1) { throw "Expected 1 primary button, found $primaryCount" }
if ($html -match '(?i)<!doctype|<html\b|<head\b|<body\b') { throw 'Document wrapper found' }
if ($html -match '(?i)\b(fetch|XMLHttpRequest|WebSocket)\b') { throw 'Network API found' }
if ($html -match '__IMG0[1-3]__') { throw 'Unresolved image token found' }
$script = [regex]::Match($html, '<script>\s*([\s\S]*?)\s*</script>')
if (-not $script.Success) { throw 'Script block missing' }
$script.Groups[1].Value | node --check -
if ($LASTEXITCODE -ne 0) { throw 'JavaScript syntax check failed' }
[pscustomobject]@{
  Bytes = $bytes
  EmbeddedJpegs = $jpegCount
  Radios = $radioCount
  PrimaryButtons = $primaryCount
  JavaScript = 'PASS'
} | Format-List
```

Expected: size below 2 MB, three embedded JPEGs, three radios, one primary button, and JavaScript `PASS`.

- [ ] **Step 6: Run final preservation checks**

Run:

```powershell
$preserved = @(
  'output/imagegen/snorlax-headphones-2d-v3',
  'output/imagegen/snorlax-headphones-2d-v4',
  'output/imagegen/snorlax-headphones-2d-v5',
  'output/imagegen/snorlax-headphones-full-body'
)
foreach ($path in $preserved) {
  if (-not (Test-Path -LiteralPath $path -PathType Container)) {
    throw "Missing preserved preview directory: $path"
  }
}
git status --short
```

Expected: all earlier preview directories remain present; only the new v6 previews remain untracked; no platform launcher file is modified.

- [ ] **Step 7: Present the comparison**

Return:

```text
::codex-inline-vis{file="snorlax-composition-v6-compare.html"}
```

Report the exact v6 output directory, the three filenames, built-in image-edit mode, verification result, preservation of earlier previews, and that platform launcher assets remain unchanged.
