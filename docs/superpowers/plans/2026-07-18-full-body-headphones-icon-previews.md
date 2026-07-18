# Full-Body Headphones Icon Previews Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate six full-body sleepy blue-green mascot app-icon previews with glowing headphones and present them in an inline HTML comparison.

**Architecture:** Use one built-in image-generation call per visual direction, all sharing an exact full-body pose contract and no direct animation-frame inputs. Persist the six PNGs under the project, create compact embedded JPEG previews, and replace the existing thread-scoped comparison fragment with a six-choice layout.

**Tech Stack:** Built-in image generation, PNG, FFmpeg, HTML/CSS/JavaScript, Codex inline visualization renderer

## Global Constraints

- Produce exactly six 1024×1024 square preview PNGs.
- Do not replace any Heni platform icon in this iteration.
- Use the user's supplied images only to derive written traits; do not pass the animation screenshots directly to image generation.
- Every preview shows the complete front-facing seated body: two visible ears, two hands resting naturally on the cream belly, two relaxed legs stretched toward the lower corners, and two complete feet with small claws and warm brown pads.
- Every preview shows complete over-ear headphones with a cyan-to-violet glow; the headband must sit behind or above the ears so both ears remain visible.
- Keep every body part and the headphones inside generous icon-safe padding.
- Use a dark simple background, no text, no watermark, no other character, no extra or missing limbs, no tail, no hair tuft, no feline whiskers, and no complex scenery.

---

### Task 1: Generate and validate six full-body previews

**Files:**
- Create: `output/imagegen/snorlax-headphones-full-body/01-plush-3d.png`
- Create: `output/imagegen/snorlax-headphones-full-body/02-cinematic-3d.png`
- Create: `output/imagegen/snorlax-headphones-full-body/03-gouache.png`
- Create: `output/imagegen/snorlax-headphones-full-body/04-flat-poster.png`
- Create: `output/imagegen/snorlax-headphones-full-body/05-minimal-gloss.png`
- Create: `output/imagegen/snorlax-headphones-full-body/06-clay-nightlight.png`

**Interfaces:**
- Consumes: the approved design in `docs/superpowers/specs/2026-07-18-snorlax-headphones-icon-previews-design.md`
- Produces: six square PNG paths consumed by Task 2

- [ ] **Step 1: Use this exact shared pose prompt for every generation**

```text
Use case: stylized-concept
Asset type: wholesome exploratory square music app-icon preview.
Primary request: Create an original enormous, extremely round, sleepy blue-green and warm-cream bear-like fantasy mascot wearing complete over-ear headphones. Show its entire seated body. It sits front-facing with a gigantic round cream belly, both short arms relaxed naturally on top of the belly, and both short legs lazily stretched and splayed toward the lower corners. Show both complete feet with three small cream claws and warm brown oval foot pads facing partly toward the viewer. Its eyes are closed with a tiny peaceful smile. It has two small pointed ears, and both ears must remain fully visible above or inside the headphone arc.
Headphones: one coherent over-ear headset; complete cyan-to-violet glowing ear cups on both sides; a complete headband arcs behind or above the ears; glow softly illuminates cheeks, hands, belly edges, and feet without overexposure.
Composition: centered symmetrical full-body portrait; the character occupies 78–82% of the square; generous empty padding around the headband, ears, hands, legs, and feet; readable at 64×64.
Character constraints: deep blue-green outer body; large warm-cream face and belly; extremely round torso; very short limbs; no tail; no hair tuft; no whiskers; no pronounced cat muzzle.
Scene: simple dark midnight navy radial background with no floor, furniture, forest, food, or narrative objects.
Avoid: text, letters, logo, watermark, border, other characters, extra limbs, missing limbs, merged hands, cropped feet, cropped ears, deformed headphones, standing, running, crossed legs, or hugging knees.
```

- [ ] **Step 2: Generate `01-plush-3d.png`**

Append this exact style block to the shared pose prompt and use the built-in image generator:

```text
Style: soft short-pile plush 3D toy; subtle fabric fibers and gentle compression where the hands rest on the belly; rounded feet and paws; calm bedtime softness; controlled cyan-violet bloom.
```

- [ ] **Step 3: Generate `02-cinematic-3d.png`**

Append this exact style block to the shared pose prompt and use the built-in image generator:

```text
Style: polished cinematic rounded 3D app-icon character; smooth premium surfaces, precise headphone construction, soft volumetric rim light, clear cream face and belly color blocking, refined but still cute.
```

- [ ] **Step 4: Generate `03-gouache.png`**

Append this exact style block to the shared pose prompt and use the built-in image generator:

```text
Style: original nostalgic gouache mascot poster; hand-painted opaque shapes, softly imperfect dark contour, subtle paper grain, warm sleepy mood, restrained modern neon headphone highlights.
```

- [ ] **Step 5: Generate `04-flat-poster.png`**

Append this exact style block to the shared pose prompt and use the built-in image generator:

```text
Style: clean night-color graphic poster; bold simplified color blocks, crisp rounded silhouette, minimal shading, strong full-body readability, cyan-violet headset glow rendered as simple luminous shapes.
```

- [ ] **Step 6: Generate `05-minimal-gloss.png`**

Append this exact style block to the shared pose prompt and use the built-in image generator:

```text
Style: minimal glossy modern app icon; very limited detail, smooth gradients, clean geometric curves, premium restrained highlights, strongest possible recognition of ears, hands, belly, legs, feet, and headset at small size.
```

- [ ] **Step 7: Generate `06-clay-nightlight.png`**

Append this exact style block to the shared pose prompt and use the built-in image generator:

```text
Style: matte soft-clay figurine with gentle handmade rounding; diffuse bedtime night-light atmosphere; glowing ear cups behave like small cyan-violet lamps; extra soothing and cute without losing silhouette clarity.
```

- [ ] **Step 8: Inspect every output before accepting it**

Open every PNG and verify the full-body contract, two visible ears, two separate hands on the belly, two relaxed legs, two complete feet, coherent headphones, controlled glow, safe padding, and absence of prohibited details. Regenerate only a failing output with one targeted correction.

- [ ] **Step 9: Normalize and verify PNG dimensions**

Run:

```powershell
$outDir = 'output/imagegen/snorlax-headphones-full-body'
Get-ChildItem -LiteralPath $outDir -Filter '*.png' | ForEach-Object {
  $normalized = Join-Path $outDir ($_.BaseName + '-1024.png')
  ffmpeg -hide_banner -loglevel error -y -i $_.FullName -vf 'scale=1024:1024:flags=lanczos' $normalized
  if ($LASTEXITCODE -ne 0) { throw "Resize failed: $($_.Name)" }
  Move-Item -LiteralPath $normalized -Destination $_.FullName -Force
}
```

Expected: exactly six PNGs, each 1024×1024.

### Task 2: Replace the comparison HTML with six choices

**Files:**
- Modify: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-headphones-compare.html`
- Create: six 320×320 JPEG thumbnails beside the fragment
- Create: six PNG copies beside the fragment

**Interfaces:**
- Consumes: the six normalized PNGs from Task 1
- Produces: a responsive six-choice inline comparison

- [ ] **Step 1: Copy PNGs and create compact comparison thumbnails**

Run:

```powershell
$outDir = 'output/imagegen/snorlax-headphones-full-body'
$visualDir = 'C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790'
Get-ChildItem -LiteralPath $outDir -Filter '*.png' | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $visualDir $_.Name) -Force
  ffmpeg -hide_banner -loglevel error -y -i $_.FullName -vf 'scale=320:320:flags=lanczos' -q:v 7 (Join-Path $visualDir ($_.BaseName + '-preview.jpg'))
  if ($LASTEXITCODE -ne 0) { throw "Thumbnail failed: $($_.Name)" }
}
```

- [ ] **Step 2: Replace the HTML fragment**

Create a fragment with the unique root ID `snorlax-headphones-compare`, a responsive `.viz-grid`, six radio choices, one 320×320 JPEG data URI per choice, concise Chinese labels, and one `.btn.btn-primary` confirmation button. Keep the local JavaScript action `window.openai.sendFollowUpMessage`, and include the selected number and direction in the follow-up prompt.

- [ ] **Step 3: Validate the fragment and assets**

Run checks that prove: the fragment is under 2 MB; it contains exactly six embedded JPEG images and six radio inputs; it contains no document wrapper or remote network calls; its inline JavaScript passes `node --check -`; and the project directory contains exactly six valid 1024×1024 PNGs.

- [ ] **Step 4: Present the comparison**

Return `::codex-inline-vis{file="snorlax-headphones-compare.html"}` and ask the user which numbered direction should be refined. Report the six project PNG paths and the built-in image-generation prompt set.

