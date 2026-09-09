# Tilted-Head 2D Icon V5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce four consistent 1024×1024 2D icon previews with deep navy-blue body color, a 12°–15° head tilt, naturally perspective-shaped headphones, and two lazy paw poses.

**Architecture:** Start from the accepted original v3 cel-shaded belly-paw image, because targeted edits of that original output are reliable while new full redraws and old animation-frame inputs are not. Apply palette/pattern cleanup first, then head-and-headset geometry as a separate edit; derive the second pose and both picture-book variants only from accepted v5 originals.

**Tech Stack:** Built-in image editing, PNG, FFmpeg, HTML/CSS/JavaScript, Codex inline visualization renderer

## Global Constraints

- Produce exactly four new 1024×1024 PNGs under `output/imagegen/snorlax-headphones-2d-v5/`.
- Preserve every v3, v4, full-body, and small-head preview.
- Use `output/imagegen/snorlax-headphones-2d-v3/01-cel-belly-paws.png` only as the accepted original edit base; never send the animation screenshots to image generation.
- Use low-saturation deep navy/slate blue body color, warm yellow-cream face and belly, ivory claws, warm-brown sole pads, and darker navy outlines.
- Remove cheek stripes, side stripes, spots, whiskers, and every other decorative pattern.
- Keep the body front-facing and stable; tilt the complete head, face, pointed ears, and headset 12°–15° toward the image right.
- Use medium-sized matte dark-indigo oval ear cups with natural high/low and near/far difference; use one continuous diagonal headband and a single narrow cyan-violet rim glow.
- Require exactly three claw tips on each hand and three toe claws on each foot.
- Keep the huge belly dominant, complete feet visible, eyes closed, expression peaceful, and all parts inside icon-safe padding.
- Belly-paw cells use two naturally resting paws; headphone-paw cells use the image-right paw on the lower near ear-cup rim and the other paw resting on the belly.
- No realistic fur, plush, clay, plastic, 3D rendering, text, watermark, extra character, extra or missing limb, malformed headset, or cropped body part.

---

### Task 1: Build the v5 cel-shaded master and pose pair

**Files:**
- Base: `output/imagegen/snorlax-headphones-2d-v3/01-cel-belly-paws.png`
- Create: `output/imagegen/snorlax-headphones-2d-v5/01-cel-belly-paws.png`
- Create: `output/imagegen/snorlax-headphones-2d-v5/02-cel-one-paw-headphone.png`

**Interfaces:**
- Produces: two accepted v5 cel-shaded PNGs consumed by Task 2

- [ ] **Step 1: Recolor and remove patterns from the accepted v3 base**

Use a built-in precise-object edit that changes only surfaces: outer body becomes low-saturation deep navy/slate blue, face and belly become warm yellow-cream, claws remain ivory, sole pads remain warm brown, and outlines become darker navy. Remove every cheek and body stripe; replace any required modeling with one broad same-hue shadow per region. Preserve composition, pose, claws, feet, face, ears, headset, and 2D linework.

- [ ] **Step 2: Inspect the palette intermediate**

Reject pale gray-blue, bright cyan-green, stripes, spots, forehead markings, or cat whiskers. Require exactly three claws per hand and foot and the original natural belly-paw pose.

- [ ] **Step 3: Tilt the head and rebuild the headset**

Use the accepted palette intermediate as a precise edit target. Rotate only the complete head unit—face patch, facial features, pointed ears, and headset—12°–15° toward the image right while keeping the body stable. Replace headphones with medium matte dark-indigo oval cups: the image-right lower/near cup is fully visible and subtly larger, the image-left far cup is slightly higher and farther back, both remain coherent. Add one continuous medium-thin diagonal headband behind the ears and one narrow cyan-violet outer rim glow. Preserve the exact belly-paw pose, palette, claw counts, body, legs, feet, background, and padding.

- [ ] **Step 4: Accept and persist `01-cel-belly-paws.png`**

Require a clearly tilted face and eyes, pointed ears following the same tilt, a headset that reads as one wearable object, medium ear cups instead of tiny modules or bulky rings, visible safe padding, and natural belly paws.

- [ ] **Step 5: Create `02-cel-one-paw-headphone.png` from accepted 01**

Change only arms and hands. The image-right arm lifts in a low relaxed curve so its three claws lightly touch the lower outside rim of the near/lower ear cup without hiding the ear or main glow. The image-left paw stays naturally on the belly with wrist following the belly arc and three claws visible. Preserve head tilt, headset perspective, palette, no-pattern surfaces, feet, toe claws, linework, background, and padding.

- [ ] **Step 6: Inspect and persist 02**

Require one paw on the low ear-cup rim, one paw on the belly, two sets of exactly three hand claws, two feet with exactly three toe claws, and no stiff or symmetric raised-arm pose.

### Task 2: Build the v5 picture-book pair

**Files:**
- Create: `output/imagegen/snorlax-headphones-2d-v5/03-storybook-belly-paws.png`
- Create: `output/imagegen/snorlax-headphones-2d-v5/04-storybook-one-paw-headphone.png`

**Interfaces:**
- Consumes: accepted Task 1 PNGs
- Produces: two accepted picture-book PNGs

- [ ] **Step 1: Style-transfer accepted 01 into 03**

Preserve every shape, pose, head tilt, headset perspective, palette, no-pattern rule, claw count, and composition. Change only the art treatment to soft slightly imperfect navy hand-drawn outlines, large flat gouache-like shapes, restrained paper or colored-pencil grain, minimal same-hue shading, and hand-painted narrow cyan-violet rim glow.

- [ ] **Step 2: Inspect and persist 03**

Require exact geometry pairing with 01, controlled picture-book texture, no pattern-like shading, unmistakable 2D presentation, natural belly paws, and correct claw counts.

- [ ] **Step 3: Style-transfer accepted 02 into 04**

Preserve every shape, one-paw headphone pose, head tilt, headset perspective, palette, no-pattern rule, claw count, and composition. Apply exactly the same picture-book treatment used for 03 and make no anatomy or pose change.

- [ ] **Step 4: Inspect and persist 04**

Require exact pose pairing with 02 and style pairing with 03; one paw stays on the belly, one lightly touches the lower near cup, both ears and rim glow remain visible, and claw counts are exact.

### Task 3: Normalize, validate, and present

**Files:**
- Verify: `output/imagegen/snorlax-headphones-2d-v5/*.png`
- Modify: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-headphones-compare.html`
- Create: four compact v5 JPEG thumbnails beside the fragment

**Interfaces:**
- Consumes: four accepted v5 PNGs
- Produces: four normalized PNGs and a four-choice comparison

- [ ] **Step 1: Normalize and verify PNGs**

Use FFmpeg Lanczos scaling to normalize exactly four PNGs to 1024×1024. Use `System.Drawing.Image` to verify count, dimensions, and PNG format GUID `b96b3caf-0728-11d3-9d7b-0000f81ef32e`.

- [ ] **Step 2: Create four compact JPEG previews**

Create 400×400 JPEGs with FFmpeg Lanczos scaling and `-q:v 5`.

- [ ] **Step 3: Update the comparison fragment**

Keep root ID `snorlax-headphones-compare`. Embed exactly four JPEG data URIs with labels `01 赛璐璐 · 歪头肚皮爪`, `02 赛璐璐 · 歪头单爪扶耳机`, `03 绘本 · 歪头肚皮爪`, and `04 绘本 · 歪头单爪扶耳机`. Keep one `btn btn-primary` action calling `window.openai.sendFollowUpMessage` with the selected cell.

- [ ] **Step 4: Run final validation**

Prove the fragment is under 2 MB, contains exactly four embedded JPEGs and four radio inputs, contains no document wrapper, network API, unresolved placeholder, or escaped markup, and its JavaScript passes `node --check -`. Re-run PNG verification and prove earlier preview directories still exist.

- [ ] **Step 5: Present the comparison**

Return `::codex-inline-vis{file="snorlax-headphones-compare.html"}` and report the v5 directory, exact edit sequence, built-in mode, verification result, and preservation of earlier previews.
