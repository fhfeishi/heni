# Three-Composition App Icon Redesign

## Goal

Produce three high-quality 1024×1024 app-icon previews that share one clean, soft semi-flat 2D visual language while exploring three distinct lazy full-body compositions. The three images are candidates only; this phase does not replace any platform launcher icon.

## Approved Reference Roles

- `37e512b80680b9c241bb447428d48683.png`: anatomy reference for round paws, three claw tips, complete feet, warm-brown sole pads, large belly, and a cute compact head. Do not copy its plush or photorealistic material treatment.
- `80fc54e9016d427af935e6473aeac60e.png`: primary style and character reference for clean 2D shapes, deep navy and warm cream color relationship, pointed ears, tilted closed-eye face, perspective headphones, and a single paw touching an ear cup.
- `stage2.jpg` and `stage3.jpg`: pose inspiration for relaxed reclining, stretched legs, belly dominance, and sleepy humor. Do not use these animation screenshots as direct edit targets; translate their pose ideas into an original composition.

## Shared Visual Language

- Use a semi-flat 2D illustration style with clean color fields and only a small amount of soft, broad same-hue modeling.
- Keep the image pure, calm, and non-glary: no realistic fur, plush fibers, clay, plastic, metallic shine, hard specular highlights, noisy texture, or aggressive neon bloom.
- Use a low-saturation deep navy/slate body, warm yellow-cream face and belly, ivory claws, warm-brown sole pads, and darker navy outlines.
- Do not add stripes, spots, forehead markings, whiskers, or decorative patterns.
- Keep a modest-sized head, pointed ears, a huge dominant belly, round hands and feet, and exactly three ivory claw tips on each hand and each foot.
- Keep all ears, hands, feet, claws, headset parts, and glow inside generous app-icon-safe padding.
- Use medium matte dark-indigo oval over-ear cups with natural near/far perspective, one coherent headband behind the ears, and one narrow cyan-to-violet outer rim glow.
- Keep the background a clean deep-navy field with a restrained soft radial halo behind the character. No scenery, text, logo, watermark, extra object, or secondary character.

## Candidate A — Centered Tilted Sit

- Keep the torso upright and front-facing.
- Tilt the complete head, face, ears, and headset 10°–12° toward image right.
- Keep the large belly central and both feet fully visible with a stable, nearly symmetrical base.
- The image-right paw lightly touches the lower outside rim of the near ear cup without hiding the pointed ear or main glow.
- The image-left paw rests naturally on the upper belly, following its curve.
- Use closed eyes and a quiet, small content smile.
- This candidate prioritizes app-icon clarity and is the most conservative evolution of the accepted v5 image.

## Candidate B — Diagonal Recline with Stretched Legs

- Recline the body along a 16°–20° diagonal instead of keeping it upright.
- Let one foot sit closer to the viewer and appear moderately larger; keep the second foot slightly farther back. Avoid exaggerated fisheye perspective.
- Keep both paws relaxed on the belly, with wrists and forearms following the reclining body rather than forming a symmetric rigid pose.
- Let the tilted head settle toward the lower ear cup so the headset feels worn rather than placed around the silhouette.
- Use closed eyes and a small open-mouth yawn or sleepy laugh with a restrained warm-coral inner mouth.
- This candidate carries the strongest lazy, comfortable personality from the animation pose references.

## Candidate C — Side-Leaning Half Recline

- Use a gentle side lean between Candidate A's upright clarity and Candidate B's full diagonal recline.
- Tilt the complete head and headset 12°–15° toward image right.
- Extend one leg toward the foreground while the other leg naturally bends or recedes; keep both complete feet and all toe claws visible.
- Let the image-right paw rest loosely on the outer edge of the near ear cup, with a softer and more draped arm than Candidate A.
- Place the image-left paw lower on the belly arc.
- Use closed eyes and a slightly broader satisfied smile than Candidate A.
- This candidate should feel playful and relaxed without losing small-size readability.

## Generation Architecture

1. Use the accepted AI-generated `output/imagegen/snorlax-headphones-2d-v5/02-cel-one-paw-headphone.png` as the only direct edit/style base.
2. Produce Candidate A through a precise polish edit that improves app-icon padding, low-glare lighting, headset coherence, and small-size readability while preserving the approved pose.
3. Produce Candidates B and C as composition changes using the accepted 2D image as the style and character anchor plus textual pose specifications. Do not send the animation screenshots as edit targets.
4. Inspect each result independently. Correct only one defect at a time, especially claw count, ear visibility, headset continuity, limb anatomy, or crop.
5. Normalize the accepted files to 1024×1024 PNG with high-quality Lanczos scaling.

## Deliverables

Create exactly three new files under `output/imagegen/snorlax-headphones-composition-v6/`:

1. `01-centered-tilted-sit.png`
2. `02-diagonal-recline.png`
3. `03-side-lean-half-recline.png`

Create a lightweight three-choice comparison after the images pass validation. Preserve every existing v3, v4, v5, full-body, small-head, and other preview asset.

## Acceptance Criteria

- Exactly three new PNG files, each 1024×1024.
- All three clearly belong to one semi-flat 2D set.
- The body uses deep navy/slate blue rather than pale gray-blue or bright turquoise.
- Face and belly use a warm, soft cream rather than stark white or saturated yellow.
- Each hand and each foot visibly has exactly three claw tips.
- Both pointed ears remain readable and are not swallowed by the headband.
- Headphones read as one wearable object with oval cups, coherent perspective, one continuous band, and restrained cyan-violet rim light.
- Candidate A has one paw on the near ear cup and one on the belly.
- Candidate B has both paws on the belly and a small open-mouth sleepy expression.
- Candidate C has one loosely draped paw on the near ear cup and the other lower on the belly.
- No cropped limb, extra limb, malformed paw, duplicate ear cup, broken headband, text, watermark, or decorative body pattern.
- At 64×64, the head tilt, belly, foot pads, and headset remain recognizable without the glow overpowering the silhouette.

## Out of Scope

- Replacing Windows, Android, iOS, or macOS launcher assets.
- Adding adaptive Android foreground/background layers.
- Editing application code or platform manifests.
- Producing a final store-submission icon before the user selects one of the three previews.
