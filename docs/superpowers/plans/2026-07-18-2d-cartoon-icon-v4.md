# 2D Cartoon Icon V4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate four consistent 1024×1024 2D cartoon icon previews with softer blue-green fur color, no decorative body patterns, smaller headphones, and two relaxed paw poses.

**Architecture:** Generate a new original cel-shaded belly-paw master from a text-only character specification so the original plush reference is not sent to the image tool. Derive the cel headphone-paw pose and both picture-book variants only from accepted original v4 outputs, persist them in a separate `v4` directory, then update the four-choice comparison.

**Tech Stack:** Built-in image generation/editing, PNG, FFmpeg, HTML/CSS/JavaScript, Codex inline visualization renderer

## Global Constraints

- Produce exactly four new 1024×1024 PNG previews in `output/imagegen/snorlax-headphones-2d-v4/`.
- Preserve all v3 and earlier preview directories.
- Use a new original pointed-ear fantasy mascot; do not pass the old plush PNG as an image input.
- Use low-saturation misty blue-green body color, warm yellow-cream face and belly, ivory claws, warm-brown sole pads, and deep navy outlines.
- Use no cheek stripes, side stripes, spots, forehead point, feline whiskers, or other decorative body pattern.
- Keep head height at or below about 34% of complete character height; huge round belly dominates.
- Make ear cups 15%–20% smaller than the v3 versions, slightly lower and behind the pointed ears; use a thin headband and narrow cyan-violet rim glow.
- Place the complete character about 3% lower in the square with extra top padding.
- Require exactly three visible ivory claw tips on each hand and exactly three visible ivory toe claws on each foot.
- Keep a front-facing lazy seated pose, closed eyes, tiny peaceful smile, complete legs and feet, and a simple dark-blue icon background.
- No text, watermark, extra character, complex scenery, extra or missing limb, cropped body part, realistic fur, plush, clay, plastic, or 3D-rendered material response.

---

### Task 1: Generate the cel-shaded v4 pair

**Files:**
- Create: `output/imagegen/snorlax-headphones-2d-v4/01-cel-belly-paws.png`
- Create: `output/imagegen/snorlax-headphones-2d-v4/02-cel-headphone-paws.png`

**Interfaces:**
- Produces: two accepted original cel-shaded PNGs used by Task 2

- [ ] **Step 1: Generate `01-cel-belly-paws.png` from text only**

Use one built-in generate call with this exact specification:

```text
Use case: stylized-concept
Asset type: exploratory square 2D music app-icon preview.
Primary request: Create a new original cute and lazy pointed-ear fantasy mascot with an enormous round body and huge belly, wearing one compact over-ear headset. This must not exactly resemble any existing franchise character. Draw it as an unmistakably semi-flat cel-shaded 2D animation icon.
Character: low-saturation misty blue-green outer body; complete soft oval warm yellow-cream face patch with no forehead point; enormous warm yellow-cream belly; deep navy outlines; two small softly pointed ears; short rounded hand paws; thick rounded feet; ivory blunt claws; warm-brown oval sole pads. No cheek stripes, body stripes, spots, forehead marking, whiskers, or other pattern.
Proportions: head including ears is at most 34% of complete character height; huge torso and belly have at least twice the visual area of the head; body-first silhouette.
Pose: front-facing lazy seated pose; both arms fall loosely from the shoulders; both rounded hand paws rest under their own weight on the upper left and upper right belly curve; wrists follow the belly arc; left and right placement differ slightly; exactly three ivory claw tips per hand point gently toward the belly without pressing, gripping, wrinkling, or hovering. Both legs splay toward the lower corners; both complete feet show one brown oval sole pad and exactly three ivory toe claws.
Headphones: compact ear cups 15%–20% smaller than typical mascot headphones, placed slightly lower and behind the pointed ears; thin complete headband; narrow cyan-to-violet rim light on the outer edges only; no bulky luminous rings.
Composition: complete character occupies 78%–82% of the square and sits about 3% lower than a centered composition; extra top breathing room; safe padding around ears, headset, paws, and feet.
Face: short soft closed-eye curves and a tiny relaxed smile; simple round nose; cute, sleepy, calm.
Style: smooth rounded deep-navy outlines, large clean flat color shapes, at most one soft same-hue shadow per region, minimal gradients, no paper texture, no realistic material texture, no 3D volume rendering.
Avoid: copyrighted character replication, realistic fur, plush, clay, plastic, 3D rendering, photographic light, cat stripes, cheek stripes, body markings, oversized head, oversized headphones, giant eyes, sharp claws, extra or missing claws, extra or missing limbs, cropped ears or feet, text, watermark, border, or complex scenery.
```

- [ ] **Step 2: Inspect 01 before accepting it**

Require natural relaxed belly paws, exactly three claws per hand and foot, no pattern, softer palette, compact headset behind both ears, unmistakable 2D style, and complete safe padding. If one item fails, regenerate or precisely edit only that item.

- [ ] **Step 3: Generate `02-cel-headphone-paws.png` from accepted 01**

Use accepted 01 as the edit target. Change only the arms and hands: both shoulders and elbows stay low; each rounded paw lightly touches the lower outside rim of its nearest ear cup; exactly three claws per hand remain visible; neither paw covers the pointed ears or the main rim glow; belly, feet, colors, compact headset, linework, and composition remain unchanged.

- [ ] **Step 4: Inspect 02 before accepting it**

Require two separate relaxed paws touching two separate lower ear-cup rims, exactly three claws per hand and foot, visible pointed ears, visible rim glow, unobstructed belly, and exact cel-style consistency with 01.

### Task 2: Generate the picture-book v4 pair

**Files:**
- Create: `output/imagegen/snorlax-headphones-2d-v4/03-storybook-belly-paws.png`
- Create: `output/imagegen/snorlax-headphones-2d-v4/04-storybook-headphone-paws.png`

**Interfaces:**
- Consumes: accepted Task 1 PNGs
- Produces: two accepted picture-book PNGs

- [ ] **Step 1: Generate `03-storybook-belly-paws.png` from accepted 01**

Use accepted 01 as the style-transfer target. Preserve all geometry, pose, claw count, palette, no-pattern rule, compact headset, and composition. Change only the art treatment to soft slightly imperfect deep-navy hand-drawn linework, flat gouache-like color shapes, restrained paper or colored-pencil grain, minimal hand-painted same-hue shading, and simple hand-painted cyan-violet rim glow. Keep it clearly 2D and crisp at 64×64.

- [ ] **Step 2: Inspect 03 before accepting it**

Require the same natural belly-paw anatomy and compact-headset composition as 01, a visible but restrained picture-book texture, no stripe-like shading, and exact claw counts.

- [ ] **Step 3: Generate `04-storybook-headphone-paws.png` from accepted 02**

Use accepted 02 as the style-transfer target. Preserve all geometry, headphone-paw pose, claw count, palette, no-pattern rule, compact headset, visible ears, visible rim glow, and composition. Apply exactly the same picture-book treatment specified for 03 and make no pose or anatomy changes.

- [ ] **Step 4: Inspect 04 before accepting it**

Require exact pose pairing with 02, exact style pairing with 03, three claws per hand and foot, visible ears and rim glow, unobstructed belly, no patterns, and no 3D rendering.

### Task 3: Normalize, validate, and compare

**Files:**
- Verify: `output/imagegen/snorlax-headphones-2d-v4/*.png`
- Modify: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-headphones-compare.html`
- Create: four compact v4 JPEG thumbnails beside the fragment

**Interfaces:**
- Consumes: four accepted Task 1–2 PNGs
- Produces: exactly four normalized PNGs and a selectable comparison

- [ ] **Step 1: Normalize all four PNGs**

Use FFmpeg Lanczos scaling to create exactly four 1024×1024 PNGs in place. Fail if file count is not four.

- [ ] **Step 2: Verify file format and dimensions**

Use `System.Drawing.Image` to prove every v4 file is a 1024×1024 PNG with format GUID `b96b3caf-0728-11d3-9d7b-0000f81ef32e`.

- [ ] **Step 3: Build four compact JPEG previews**

Create 400×400 JPEG thumbnails with FFmpeg Lanczos scaling and `-q:v 5`.

- [ ] **Step 4: Update the comparison fragment**

Keep root ID `snorlax-headphones-compare`. Embed exactly four JPEG data URIs in matrix order with labels `01 赛璐璐 · 自然肚皮爪`, `02 赛璐璐 · 轻扶耳机`, `03 绘本 · 自然肚皮爪`, and `04 绘本 · 轻扶耳机`. Keep one `btn btn-primary` action calling `window.openai.sendFollowUpMessage` with the selected cell.

- [ ] **Step 5: Run final validation**

Prove the fragment is under 2 MB, has exactly four embedded JPEGs and four radio inputs, has no document wrapper, network API, unresolved placeholder, or escaped markup, and its JavaScript passes `node --check -`. Re-run the PNG count, dimensions, and format check; verify all earlier preview directories still exist.

- [ ] **Step 6: Present the four-way comparison**

Return `::codex-inline-vis{file="snorlax-headphones-compare.html"}` and report the v4 directory, final prompt set, built-in mode, verification result, and preservation of earlier previews.
