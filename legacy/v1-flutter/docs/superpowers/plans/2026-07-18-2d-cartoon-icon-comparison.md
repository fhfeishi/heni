# 2D Cartoon Icon Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate exactly four high-quality 1024×1024 2D cartoon music app-icon previews arranged as two art styles by two relaxed paw poses.

**Architecture:** Use the existing plush preview only as a structural reference for silhouette, proportions, ears, headset, hands, claws, feet, and sole pads. Issue one built-in image-edit call per matrix cell with a shared strict 2D contract and a dedicated style-plus-pose block, persist accepted PNGs in a new `v3` directory, then replace the comparison with four compact selectable previews.

**Tech Stack:** Built-in image generation/editing, PNG, FFmpeg, HTML/CSS/JavaScript, Codex inline visualization renderer

## Global Constraints

- Produce exactly four new 1024×1024 PNG previews.
- Use `output/imagegen/snorlax-headphones-full-body/01-plush-3d.png` as the only structural reference image.
- Preserve the reference's small head, huge belly, pointed ears, complete headset, short rounded paws, three cream claws per hand, thick feet, brown oval sole pads, and three cream toe claws per foot.
- Remove all realistic plush fibers, photographic studio lighting, plastic highlights, realistic depth of field, soft-clay appearance, and 3D-rendered material response.
- Keep head height at or below about 34% of complete character height; body and belly dominate.
- Use a front-facing lazy seated pose, closed eyes, tiny peaceful smile, complete legs and feet, simple dark-blue icon background, and controlled cyan-to-violet 2D headset glow.
- For belly-paw poses, arms fall naturally from the shoulders, wrists follow the belly curve, paws rest under their own weight, and left/right placement has a tiny natural asymmetry.
- For headset-paw poses, both paws lightly touch the outer ear cups without squeezing, floating, merging, or hiding the ears.
- Do not overwrite any previous preview directory or formal Heni platform icon.
- No text, watermark, extra character, complex scenery, missing or extra limb, missing or extra claw, cropped body part, or malformed headset.

---

### Task 1: Generate four 2D previews

**Files:**
- Reference: `output/imagegen/snorlax-headphones-full-body/01-plush-3d.png`
- Create: `output/imagegen/snorlax-headphones-2d-v3/01-cel-belly-paws.png`
- Create: `output/imagegen/snorlax-headphones-2d-v3/02-cel-headphone-paws.png`
- Create: `output/imagegen/snorlax-headphones-2d-v3/03-storybook-belly-paws.png`
- Create: `output/imagegen/snorlax-headphones-2d-v3/04-storybook-headphone-paws.png`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-07-18-2d-cartoon-icon-comparison-design.md` and the single reference PNG
- Produces: four square PNG paths consumed by Tasks 2 and 3

- [ ] **Step 1: Use this exact shared redraw prompt for every built-in call**

```text
Use case: style-transfer
Asset type: exploratory square 2D music app-icon preview.
Input image: the supplied image is a structural character reference only. Preserve its overall front-facing seated silhouette, small-head/huge-belly proportions, pointed ears, complete over-ear headset, short rounded hand paws with exactly three small cream claw tips on each hand, thick splayed feet with brown oval sole pads and exactly three cream toe claws on each foot. Do not preserve its plush fibers, realistic 3D materials, photographic lighting, or rendered volume.
Primary request: redraw the reference mascot as an unmistakably 2D, cute, lazy cartoon app icon. The body and warm-cream belly dominate the square. Keep the head at or below about 34% of full character height. Eyes remain closed with a tiny content smile. Both pointed ears, both legs, both complete feet, all claws, and the entire coherent headset remain visible.
Headphones: one fitted over-ear headset with a complete headband behind or above the ears. Express cyan-to-violet glow as simple controlled 2D luminous shapes and one soft color halo, not realistic neon photography.
Composition: centered full-body icon composition; character occupies 78%–82% of the square; generous safe padding around headband, ears, hands, feet, and toe claws; readable at 64×64.
Color: dusky teal-blue outer body, warm cream face and huge belly, warm brown sole pads, cream claw tips, midnight-blue background, cyan-to-violet headset accents.
Quality: clean intentional drawing, stable anatomy, coherent linework, precise paw and claw shapes, crisp eyes and mouth, consistent left/right limb construction, polished professional 2D app-icon finish.
Avoid: realistic fur, plush texture, realistic 3D rendering, plastic shine, clay sculpture, photorealism, depth of field, volumetric studio light, excessive gradients, oversized head, chibi baby proportions, giant eyes, text, letters, logo, watermark, border, other characters, extra limbs, missing limbs, extra claws, missing claws, merged paws, cropped feet, cropped ears, deformed headset, standing, running, crossed legs, or complex scenery.
```

- [ ] **Step 2: Generate `01-cel-belly-paws.png`**

Append these exact blocks and make one built-in edit call with the reference path:

```text
Pose: both arms fall loosely from the shoulders. Both rounded hand paws rest naturally on the upper left and upper right curve of the huge belly. Wrists follow the belly arc; paws look supported only by their own weight; left and right placement differ very slightly like a relaxed living pose. Exactly three cream claw tips are visible on each hand, gently pointing toward the belly without pressing, scratching, gripping, wrinkling, or hovering.
Style: semi-flat cel-shaded 2D animation icon. Smooth dark-teal rounded outlines, large clean color shapes, one base color plus at most one soft shadow per region, tiny restrained 2D highlight only where necessary, crisp silhouette, no paper texture, no realistic material texture, and no 3D volume rendering.
```

- [ ] **Step 3: Generate `02-cel-headphone-paws.png`**

Append these exact blocks and make one built-in edit call with the reference path:

```text
Pose: raise both arms in a relaxed symmetrical gesture so each rounded hand paw lightly touches the outside edge of its nearest ear cup, as if gently adjusting or enjoying the music. Shoulders remain dropped and elbows relaxed. Exactly three cream claw tips on each hand curve softly around the outer ear-cup edge without squeezing, piercing, floating, merging with the headset, or covering the pointed ears. The huge belly remains unobstructed.
Style: semi-flat cel-shaded 2D animation icon. Smooth dark-teal rounded outlines, large clean color shapes, one base color plus at most one soft shadow per region, tiny restrained 2D highlight only where necessary, crisp silhouette, no paper texture, no realistic material texture, and no 3D volume rendering.
```

- [ ] **Step 4: Generate `03-storybook-belly-paws.png`**

Append these exact blocks and make one built-in edit call with the reference path:

```text
Pose: both arms fall loosely from the shoulders. Both rounded hand paws rest naturally on the upper left and upper right curve of the huge belly. Wrists follow the belly arc; paws look supported only by their own weight; left and right placement differ very slightly like a relaxed living pose. Exactly three cream claw tips are visible on each hand, gently pointing toward the belly without pressing, scratching, gripping, wrinkling, or hovering.
Style: gentle hand-drawn picture-book 2D illustration. Soft slightly imperfect dark-teal linework, flat gouache-like color shapes, very restrained colored-pencil or paper grain, minimal hand-painted shading, warm sleepy mood, crisp enough at icon size, no realistic painting, no rendered volume, and no complex illustrated scene.
```

- [ ] **Step 5: Generate `04-storybook-headphone-paws.png`**

Append these exact blocks and make one built-in edit call with the reference path:

```text
Pose: raise both arms in a relaxed symmetrical gesture so each rounded hand paw lightly touches the outside edge of its nearest ear cup, as if gently adjusting or enjoying the music. Shoulders remain dropped and elbows relaxed. Exactly three cream claw tips on each hand curve softly around the outer ear-cup edge without squeezing, piercing, floating, merging with the headset, or covering the pointed ears. The huge belly remains unobstructed.
Style: gentle hand-drawn picture-book 2D illustration. Soft slightly imperfect dark-teal linework, flat gouache-like color shapes, very restrained colored-pencil or paper grain, minimal hand-painted shading, warm sleepy mood, crisp enough at icon size, no realistic painting, no rendered volume, and no complex illustrated scene.
```

- [ ] **Step 6: Persist every accepted result non-destructively**

Copy each built-in output into its exact Task 1 path. Leave the built-in original and all previous preview directories unchanged.

### Task 2: Inspect and normalize the four PNGs

**Files:**
- Verify: `output/imagegen/snorlax-headphones-2d-v3/*.png`

**Interfaces:**
- Consumes: four Task 1 PNGs
- Produces: exactly four accepted 1024×1024 PNGs for the comparison

- [ ] **Step 1: Inspect each image against its matrix cell**

Verify all shared invariants, then verify 01/03 have naturally resting belly paws with relaxed wrists and tiny asymmetry, 02/04 have both paws lightly touching separate ear cups, 01/02 use semi-flat cel shading, and 03/04 use restrained hand-drawn picture-book texture.

- [ ] **Step 2: Reject any image that still reads as 3D**

Reject realistic fur, rendered material shine, sculpted volume, photographic depth, or studio-light falloff. Regenerate only the failing matrix cell with one targeted correction; never add a fifth delivered candidate.

- [ ] **Step 3: Reject paw, claw, or headset anatomy failures**

Require exactly two hand paws, exactly three visible cream claws on each hand, exactly two complete feet, exactly three visible toe claws on each foot, and one coherent headset. Regenerate only the failing matrix cell with a single anatomy correction.

- [ ] **Step 4: Normalize dimensions**

Run:

```powershell
$outDir = 'D:/codespace/fhfeishi/heni/output/imagegen/snorlax-headphones-2d-v3'
$files = Get-ChildItem -LiteralPath $outDir -Filter '*.png' | Sort-Object Name
if ($files.Count -ne 4) { throw "Expected exactly 4 PNGs, found $($files.Count)." }
foreach ($file in $files) {
  $temp = Join-Path $outDir ($file.BaseName + '-1024.png')
  ffmpeg -hide_banner -loglevel error -y -i $file.FullName -vf 'scale=1024:1024:flags=lanczos' $temp
  if ($LASTEXITCODE -ne 0) { throw "Resize failed: $($file.Name)" }
  Move-Item -LiteralPath $temp -Destination $file.FullName -Force
}
```

- [ ] **Step 5: Verify count, dimensions, and PNG format**

Use `System.Drawing.Image` to prove exactly four files exist and every file is a valid 1024×1024 PNG with format GUID `b96b3caf-0728-11d3-9d7b-0000f81ef32e`.

### Task 3: Replace the comparison with a four-cell matrix

**Files:**
- Modify: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-headphones-compare.html`
- Create: four compact JPEG thumbnails beside the fragment

**Interfaces:**
- Consumes: four accepted Task 2 PNGs
- Produces: a responsive four-choice comparison and confirmation action

- [ ] **Step 1: Create four 400×400 JPEG previews**

Use FFmpeg Lanczos scaling and `-q:v 5`, one JPEG for each matrix cell.

- [ ] **Step 2: Update the comparison fragment**

Keep root ID `snorlax-headphones-compare`. Show exactly four embedded JPEG data URIs in matrix order with radio labels `01 赛璐璐 · 肚皮爪`, `02 赛璐璐 · 扶耳机`, `03 绘本 · 肚皮爪`, and `04 绘本 · 扶耳机`. Keep one `btn btn-primary` confirmation action that calls `window.openai.sendFollowUpMessage` with the selected cell.

- [ ] **Step 3: Validate assets and interaction**

Prove the fragment is under 2 MB, contains exactly four embedded JPEGs and four radio inputs, contains no document wrapper, remote network API, unresolved placeholder, or escaped markup, and its inline JavaScript passes `node --check -`. Re-run Task 2's exact PNG verification before delivery.

- [ ] **Step 4: Present the four-way comparison**

Return `::codex-inline-vis{file="snorlax-headphones-compare.html"}` and report the new `v3` output directory, the exact prompt set, built-in edit mode, and verification result. State that previous previews remain preserved and no formal app icon was replaced.
