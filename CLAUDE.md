# AI Talking Head Pipeline

**Stack:** Bash, Node.js (HyperFrames CLI), Hedra API, ffmpeg

## What

Turns a portrait photo, a voice recording, and a word-level transcript into a talking-head video with designed on-screen captions using Hedra's Character-3 API for avatar generation and HyperFrames for HTML-to-video composition.

## Quick Start

```bash
./setup.sh                          # First-time setup
export HEDRA_API_KEY="..."
./generate-hedra-video.sh           # Avatar generation (Hedra)
npx hyperframes check public        # Lint composition
npx hyperframes render public -o output.mp4 --fps 25  # Final render
```

## Pipeline

**Stage 1: Avatar generation**
```bash
./generate-hedra-video.sh [image] [audio] [output]
```
Uploads a portrait and audio to Hedra, requests a Character-3 generation, polls for completion, and downloads the lip-synced video.

**Stage 2: Caption composition**

Re-encode the Hedra output with dense keyframes (HyperFrames needs them):
```bash
ffmpeg -y -i hedra-output.mp4 -c:v libx264 -crf 18 -g 25 -keyint_min 25 \
  -pix_fmt yuv420p -movflags +faststart -c:a aac public/input-video.mp4
```

Customize `public/index.html` (captions, timing, colors), then render:
```bash
npx hyperframes check public
npx hyperframes render public -o output.mp4 --fps 25 -q high
```

## Architecture

```
generate-hedra-video.sh     → Hedra API → hedra-output.mp4 (sparse keyframes)
                                              ↓
                                          ffmpeg (dense reencoding)
                                              ↓
                                          public/input-video.mp4
                                              ↓
public/index.html (GSAP timeline)  ←    HyperFrames renderer
(captions + timing + design)             ↓
                                    output.mp4 (final)
```

The composition is a single HTML file that reads `input-video.mp4` and overlays GSAP-driven captions with kinetic typography, keyword highlights, and step chips. Timing is set via `data-start` / `data-duration` attributes on card elements.

## Design System

All styling lives in `public/index.html` `<style>`:

- **Colors** — `:root` defines `--bg`, `--text`, `--accent-0` through `--accent-4`
- **Typography** — Inter font (woff2, 400/700 weights), monospace for kickers
- **Layout** — Fixed 1080 × 1350 px (portrait video format), absolute positioning
- **Motion** — GSAP `<script>` block at end of HTML (kineticChars, maskReveal, growX, slideInBottom, fadeIn)

Card markup follows `.card-host > .card > .cap-root` hierarchy, with `.cap-kicker`, `.cap-title`, `.cap-detail`, and `.hl` (keyword highlight) inside. See `transcript.example.json` for word-level timing reference when authoring captions.

## Configuration

```env
HEDRA_API_KEY=                  # Required: get from https://www.hedra.com/develop/api-keys
HEDRA_MODEL=hedra-character-3   # Optional
HEDRA_ASPECT_RATIO=3:4          # Optional
HEDRA_RESOLUTION=720p           # Optional
HEDRA_PROMPT=...                # Optional
```

See `.env.example` and the script header for defaults and Hedra's API schema for allowed values.

## No Build / No Tests

This is a pipeline script + static HTML composition. No test framework or build step — linting happens via `npx hyperframes check public` before rendering.

## Files

- `generate-hedra-video.sh` — Hedra API interaction
- `public/index.html` — HyperFrames composition (design system + GSAP timeline)
- `public/hyperframes.json` — HyperFrames project config
- `public/vendor/gsap.min.js` — GSAP library (MIT)
- `public/fonts/` — Inter typeface (OFL)
- `transcript.example.json` — Word-level timing reference
