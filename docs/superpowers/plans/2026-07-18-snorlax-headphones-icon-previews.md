# Snorlax Headphones Icon Previews Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate three exploratory Snorlax-with-glowing-headphones app-icon previews and present them in an inline HTML comparison that supports a clear visual choice.

**Architecture:** Use one built-in image-generation call per visual direction, with the four supplied images treated only as character references. Persist the PNG previews under the project, copy them beside a thread-scoped HTML fragment, and render the fragment through Codex's visualization host for comparison.

**Tech Stack:** Built-in image generation, PNG, HTML/CSS, Codex inline visualization renderer, local browser visual inspection

## Global Constraints

- Produce exactly three 1024×1024 square preview PNGs.
- Do not replace any Heni platform icon in this iteration.
- Use the supplied images only to preserve Snorlax's body colors, round proportions, short ears, and relaxed expression.
- Every preview must show complete over-ear headphones with a cyan-to-violet glow.
- Use a dark background, generous icon-safe padding, no text, no watermark, no other character, and no complex scenery.
- The three visual directions are rounded 3D badge, retro cel animation, and minimal glossy icon.

---

### Task 1: Generate and validate the three preview images

**Files:**
- Create: `output/imagegen/snorlax-headphones-previews/rounded-3d.png`
- Create: `output/imagegen/snorlax-headphones-previews/retro-cel.png`
- Create: `output/imagegen/snorlax-headphones-previews/minimal-gloss.png`

**Interfaces:**
- Consumes: reference images `D:/Ddesktop/tututu/bizhi/stage1.jpg`, `stage2.jpg`, `stage3.jpg`, and `1701531240185.jpg`
- Produces: three square PNG paths consumed by Task 2

- [ ] **Step 1: Generate the rounded 3D badge preview**

Use the built-in image generator with all four files as reference images and this prompt:

```text
Use case: stylized-concept
Asset type: exploratory square app-icon preview
Primary request: Snorlax wearing complete over-ear headphones whose ear cups and headband accents glow cyan through violet.
Input images: all four supplied images are character-form references only; preserve the recognizable dark blue-green body, cream face and belly, short pointed ears, very round proportions, and sleepy relaxed expression. Do not copy their poses or backgrounds.
Scene/backdrop: simple deep midnight blue-to-black radial gradient.
Style/medium: polished rounded 3D character badge, soft toy-like surfaces, refined app-icon rendering.
Composition/framing: centered front-facing head-and-upper-body portrait, symmetric silhouette, full ears and full headphones visible, generous safe padding, readable at 64×64.
Lighting/mood: calm nocturnal studio lighting; headphone glow softly lights the cheeks and body edges without overexposure.
Constraints: 1:1 square; no text; no watermark; no border; no extra characters; no extra limbs; no cropped ears or headphones; no forest or room scene.
```

- [ ] **Step 2: Generate the retro cel-animation preview**

Use the same four reference images with this prompt:

```text
Use case: illustration-story
Asset type: exploratory square app-icon preview
Primary request: Snorlax wearing complete over-ear headphones whose ear cups glow cyan through violet.
Input images: all four supplied images are character-form references only; preserve the recognizable dark blue-green body, cream face and belly, short pointed ears, very round proportions, and sleepy relaxed expression. Do not copy their poses or backgrounds.
Scene/backdrop: simple deep navy circular glow, no scenery.
Style/medium: warm retro cel-animation illustration, clean hand-drawn contour, flat color shapes, very subtle analog grain; modern luminous headphones provide the only neon accent.
Composition/framing: centered front-facing head-and-upper-body portrait, full ears and headphones visible, generous safe padding, readable at 64×64.
Lighting/mood: cozy, sleepy, nostalgic; restrained cyan-violet light reflecting on the cheeks.
Constraints: 1:1 square; no text; no watermark; no border; no extra characters; no extra limbs; no cropped ears or headphones; no forest or room scene.
```

- [ ] **Step 3: Generate the minimal glossy preview**

Use the same four reference images with this prompt:

```text
Use case: logo-brand
Asset type: exploratory square app-icon preview
Primary request: a highly recognizable minimal Snorlax portrait wearing complete over-ear headphones with cyan-to-violet glowing ear cups.
Input images: all four supplied images are character-form references only; preserve the dark blue-green and cream color blocking, round silhouette, short pointed ears, and relaxed closed-eye expression. Do not copy their poses or backgrounds.
Scene/backdrop: clean near-black navy gradient with a restrained circular halo.
Style/medium: minimal glossy modern app icon, simplified shapes, smooth gradients, crisp silhouette, very limited detail.
Composition/framing: centered and symmetrical head-and-upper-body portrait, full ears and full headphones visible, generous safe padding, optimized for 64×64 recognition.
Lighting/mood: calm premium music-player identity; controlled cyan-violet headphone glow.
Constraints: 1:1 square; no typography; no watermark; no border; no extra characters; no extra limbs; no cropped ears or headphones; no scenery.
```

- [ ] **Step 4: Inspect the three outputs**

Open each PNG and verify: recognizable Snorlax colors and silhouette, complete headphone geometry, visible but controlled glow, safe padding, distinct style, and absence of text, watermark, other characters, extra limbs, or scenery. Regenerate only an output that fails one of these checks, using a single targeted correction.

- [ ] **Step 5: Verify file properties**

Run:

```powershell
Get-ChildItem output/imagegen/snorlax-headphones-previews/*.png |
  ForEach-Object { $_.FullName; magick identify -format '%wx%h %m\n' $_.FullName }
```

Expected: three files, each reported as `1024x1024 PNG`.

### Task 2: Build and verify the comparison HTML

**Files:**
- Create: `C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-headphones-compare.html`
- Create copies beside the HTML: `rounded-3d.png`, `retro-cel.png`, `minimal-gloss.png`

**Interfaces:**
- Consumes: the three project PNGs produced by Task 1
- Produces: an inline comparison with three selectable visual directions

- [ ] **Step 1: Copy the previews beside the fragment**

Run:

```powershell
$visualDir = 'C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790'
Copy-Item -LiteralPath 'output/imagegen/snorlax-headphones-previews/rounded-3d.png' -Destination "$visualDir/rounded-3d.png"
Copy-Item -LiteralPath 'output/imagegen/snorlax-headphones-previews/retro-cel.png' -Destination "$visualDir/retro-cel.png"
Copy-Item -LiteralPath 'output/imagegen/snorlax-headphones-previews/minimal-gloss.png' -Destination "$visualDir/minimal-gloss.png"
```

- [ ] **Step 2: Create the HTML fragment**

Create a theme-aware fragment with a unique root ID, a responsive three-column `.viz-grid`, one semantic selection button per preview, image alt text, short direction labels, and local JavaScript that keeps exactly one `aria-pressed="true"` selection. Add a clearly labeled confirmation button that calls `window.openai.sendFollowUpMessage` with the selected direction.

- [ ] **Step 3: Render and inspect the fragment**

Run the bundled visualization renderer with `--serve`, open the served page in the in-app browser, and inspect wide and narrow layouts. Confirm that all three images load, labels remain readable, selection works by mouse and keyboard, and no horizontal clipping occurs.

- [ ] **Step 4: Validate fragment integrity**

Run:

```powershell
$fragment = 'C:/Users/10354/.codex/visualizations/2026/07/18/019f7344-f45e-7130-8e71-2d4eb0cc2790/snorlax-headphones-compare.html'
Select-String -LiteralPath $fragment -Pattern '<!doctype|<html|<head|<body|fetch\(|XMLHttpRequest|WebSocket' -CaseSensitive:$false
```

Expected: no matches.

- [ ] **Step 5: Present the comparison**

Return the inline visualization directive for `snorlax-headphones-compare.html` and ask the user to select the direction worth refining into a final icon.
