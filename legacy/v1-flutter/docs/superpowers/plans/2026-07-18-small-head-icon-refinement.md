# Small-Head Icon Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate exactly three higher-quality 1024×1024 music app-icon previews whose head-and-headset unit is visually about 15% smaller than the previous set.

**Architecture:** Generate each style from scratch with the built-in image generator and a shared body-first proportion contract, rather than geometrically editing the previous images. Persist the accepted PNGs in a new versioned directory, inspect each independently, normalize dimensions, then replace the inline comparison with only the three refined choices.

**Tech Stack:** Built-in image generation, PNG, FFmpeg, HTML/CSS/JavaScript, Codex inline visualization renderer

## Global Constraints

- Produce exactly three new 1024×1024 PNG previews.
- Do not overwrite the previous six previews or any Heni platform icon.
- Head, face patch, ears, and headset form one visual unit that is about 15% smaller than the previous set.
- The head occupies about 30%–34% of the complete character height; the torso and cream belly dominate the silhouette.
- Show two complete rounded ears, two separate hands on the belly, two relaxed legs, two complete feet, and one coherent fitted over-ear headset.
- Use an original dusky-teal and warm-cream bear-like fantasy mascot; use no animation screenshots as direct image inputs.
- Use a simple dark background, controlled cyan-to-violet glow, safe icon padding, no text, no watermark, no extra character, no extra or missing limb, and no complex scenery.
- Reject low-detail generic renders, melted anatomy, oversized heads, oversized headsets, cropped body parts, deformed headphones, muddy materials, and blown highlights.

---

### Task 1: Generate three refined previews from scratch

**Files:**
- Create: `output/imagegen/snorlax-headphones-small-head-v2/01-plush-studio.png`
- Create: `output/imagegen/snorlax-headphones-small-head-v2/02-cinematic-premium.png`
- Create: `output/imagegen/snorlax-headphones-small-head-v2/03-clay-nightlight.png`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-07-18-small-head-icon-refinement-design.md`
- Produces: three square PNG paths consumed by Tasks 2 and 3

- [ ] **Step 1: Use this exact shared prompt for all three generations**

```text
Use case: stylized-concept
Asset type: high-end exploratory square music app-icon preview.
Primary request: Create an original enormous, round, sleepy dusky-teal and warm-cream bear-like fantasy mascot wearing one complete fitted over-ear headset. Show the entire front-facing seated body. The body and huge cream belly are the visual focus; the head is deliberately small-to-medium and must not look chibi, baby-like, bobbleheaded, or oversized.
Proportions: compared with a typical cute mascot icon, reduce the combined head, face, ears, and headset unit by about 15%. The head including ears occupies only about 30%–34% of the complete visible character height. The round torso and cream belly have at least twice the visual area of the head. Rebuild the neck-and-shoulder transition naturally for these proportions; do not make the head look pasted on or shrunken mechanically.
Pose: centered relaxed seated pose; both short arms rest separately and naturally on top of the large belly; both short thick legs stretch lazily toward the lower corners; show both complete feet with three rounded toe beans and soft blue-violet oval sole pads partly facing the viewer. Closed eyes, tiny peaceful smile, two small rounded bear ears fully visible.
Headphones: one coherent premium over-ear headset fitted to the smaller head; complete ear cups on both sides; a complete headband arcs behind or above the ears; cyan-to-violet light softly illuminates cheeks, hands, belly edges, and feet without overexposure. The headset must scale with the head and must not look oversized, floating, or crushing the ears.
Composition: the complete character occupies 78%–82% of the square; balanced icon-safe padding around headband, ears, hands, legs, and feet; body-first silhouette remains readable at 64×64.
Character design: dusky-teal outer body; one simple complete warm-cream oval face patch; enormous warm-cream oval belly; rounded bear ears; rounded toe beans; blue-violet sole pads; clean anatomy and intentional forms.
Scene: simple deep midnight-navy to muted-violet radial backdrop with no floor, furniture, forest, food, or narrative object.
Quality: premium production-ready concept quality, clean edges, coherent material response, deliberate lighting, crisp facial features, precise limb separation, and polished headset construction.
Avoid: recognizable copyrighted character replication, oversized head, oversized face, giant eyes, chibi proportions, bobblehead proportions, oversized headset, generic low-detail 3D, plastic toy glare, muddy textures, excessive bloom, text, letters, logo, watermark, border, other characters, extra limbs, missing limbs, merged hands, cropped feet, cropped ears, deformed headphones, standing, running, crossed legs, hugging knees, claws, tail, hair tuft, whiskers, or cat muzzle.
```

- [ ] **Step 2: Generate `01-plush-studio.png`**

Append this style block and make one built-in image-generation call:

```text
Style: premium studio-quality soft short-pile plush 3D sculpture. Fine believable fabric fibers, subtle seam-free compression where each hand meets the belly, controlled subsurface softness, carefully shaped paws and feet, gentle cinematic key light, restrained cyan-violet rim glow, rich material separation between teal fur, cream fur, and headset. Cute but not childish; polished enough for a flagship app icon.
```

- [ ] **Step 3: Generate `02-cinematic-premium.png`**

Append this style block and make one built-in image-generation call:

```text
Style: premium cinematic rounded 3D app-icon character render. Smooth but not plastic surfaces, sophisticated soft volumetric lighting, precise cream face-and-belly color blocking, highly coherent headset engineering, crisp silhouette, subtle contact shading, controlled highlights, and refined feature placement. Favor believable volume and excellent small-size readability over exaggerated cuteness.
```

- [ ] **Step 4: Generate `03-clay-nightlight.png`**

Append this style block and make one built-in image-generation call:

```text
Style: high-end matte soft-clay collectible sculpture with gentle handmade rounding and minute surface texture. Diffuse bedtime night-light atmosphere; ear cups behave like small cyan-violet lamps with soft localized bounce light. Preserve crisp silhouette, clean facial features, separate fingers and toe beans, and premium handcrafted finish without lumpy or melted forms.
```

- [ ] **Step 5: Persist each result non-destructively**

Copy the accepted built-in outputs into the exact Task 1 paths. Do not overwrite or remove `output/imagegen/snorlax-headphones-full-body/`.

### Task 2: Inspect and normalize the three PNGs

**Files:**
- Modify only if a generation fails review: the corresponding Task 1 PNG
- Verify: `output/imagegen/snorlax-headphones-small-head-v2/*.png`

**Interfaces:**
- Consumes: the three Task 1 PNGs
- Produces: exactly three accepted 1024×1024 PNGs for the comparison

- [ ] **Step 1: Inspect all three images individually**

For each PNG, verify: head height is 30%–34% of complete character height; torso and belly dominate; ears and headset fit the smaller head; both hands, legs, and feet are complete and separate; eyes and smile are clean; materials are detailed; glow is controlled; no prohibited feature appears.

- [ ] **Step 2: Regenerate only a failing direction**

If a direction fails, repeat only that direction's built-in call and add one targeted correction describing the single failed requirement. Do not increase the number of delivered options.

- [ ] **Step 3: Normalize dimensions**

Run:

```powershell
$outDir = 'D:/codespace/fhfeishi/heni/output/imagegen/snorlax-headphones-small-head-v2'
$files = Get-ChildItem -LiteralPath $outDir -Filter '*.png' | Sort-Object Name
if ($files.Count -ne 3) { throw "Expected exactly 3 PNGs, found $($files.Count)." }
foreach ($file in $files) {
  $temp = Join-Path $outDir ($file.BaseName + '-1024.png')
  ffmpeg -hide_banner -loglevel error -y -i $file.FullName -vf 'scale=1024:1024:flags=lanczos' $temp
  if ($LASTEXITCODE -ne 0) { throw "Resize failed: $($file.Name)" }
  Move-Item -LiteralPath $temp -Destination $file.FullName -Force
}
```

- [ ] **Step 4: Verify format and count**

Use `System.Drawing.Image` to prove exactly three files exist and every file is a valid 1024×1024 PNG. Expected result: three rows, each with width `1024`, height `1024`, and PNG format GUID `b96b3caf-0728-11d3-9d7b-0000f81ef32e`.

### Task 3: Replace the comparison with only the three refined choices

**Files:**
- Modify: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-headphones-compare.html`
- Create: three compact JPEG thumbnails beside the fragment

**Interfaces:**
- Consumes: the three accepted Task 2 PNGs
- Produces: a responsive three-choice comparison and confirmation action

- [ ] **Step 1: Create 360×360 JPEG previews**

Use FFmpeg with Lanczos scaling and `-q:v 7` to create one JPEG for each accepted PNG in the visualization directory.

- [ ] **Step 2: Update the comparison fragment**

Use the existing unique root ID `snorlax-headphones-compare`. Replace the six old choices with exactly three embedded JPEG data URIs, radio labels `01 柔软毛绒 3D`, `02 电影感 3D`, and `03 软陶夜灯`, plus one `btn btn-primary` confirmation action that calls `window.openai.sendFollowUpMessage` with the selected direction.

- [ ] **Step 3: Validate the comparison and deliverables**

Prove the fragment is under 2 MB, contains exactly three embedded JPEGs and three radio inputs, has no document wrapper or remote network API, contains no unresolved placeholder, and its inline JavaScript passes `node --check -`. Re-run the exact PNG count, dimension, and format checks from Task 2 before delivery.

- [ ] **Step 4: Present only the refined comparison**

Return `::codex-inline-vis{file="snorlax-headphones-compare.html"}` and report the new project output directory, exact prompt set, built-in mode, and verification result. State that the previous six previews remain preserved and no formal app icon was replaced.
