# AI Talking Head Pipeline

A pipeline that turns a portrait photo, a voice recording, and a word-level transcript into a talking-head video with modern, designed on-screen captions. No boxed glassmorphism cards, just bold typography and keyword highlights directly over the footage.

## How It Works

1. **Avatar generation**. Hedra's Character-3 model animates a still portrait into a lip-synced talking-head video from an audio track.
2. **Caption composition**. A [HyperFrames](https://github.com/heygen-com/hyperframes) HTML composition overlays a GSAP-driven timeline of captions (kinetic titles, keyword-highlight chips, step chips) synced to a transcript, directly on the full-bleed video.
3. **Render**. The composition renders to a final MP4 via the `hyperframes` CLI.

## Stack

- **Hedra API**: avatar generation and lip-sync
- **HyperFrames**: HTML-to-video compositor (GSAP timeline, `data-*` timing attributes)
- **curl** and **jq**: API calls
- **ffmpeg**: re-encodes the generated clip with dense keyframes before compositing (required, see below)

## Prerequisites

- Bash, `curl`, `jq`
- `ffmpeg` and `ffprobe`
- Node.js (to run `npx hyperframes`)
- A Hedra API key from [hedra.com/develop/api-keys](https://www.hedra.com/develop/api-keys). Requires a paid Hedra plan; check current pricing there, it's billed per second of generated video.

## Setup

```bash
cp .env.example .env
# edit .env, or just export it directly:
export HEDRA_API_KEY="your-api-key-here"
```

## Usage

### 1. Generate the avatar clip

```bash
./generate-hedra-video.sh [image_file] [audio_file] [output_file]
# defaults: ./portrait.png ./audio.mp3 ./hedra-output.mp4
```

This uploads the image and audio to Hedra, requests a Character-3 generation, polls until it completes, and downloads the result. Useful env vars: `HEDRA_MODEL`, `HEDRA_ASPECT_RATIO`, `HEDRA_RESOLUTION`, `HEDRA_PROMPT` (see the script for defaults). Check Hedra's model schema for allowed values; `aspect_ratio` does **not** include `4:5`, the closest supported portrait ratio is `3:4`.

### 2. Re-encode with dense keyframes

The HyperFrames renderer seeks around the source video while capturing frames. A sparse keyframe interval, the default on most generated clips, causes frozen frames under the overlays. Re-encode with a keyframe every frame at your target fps before compositing:

```bash
ffmpeg -y -i hedra-output.mp4 -c:v libx264 -crf 18 -g 25 -keyint_min 25 \
  -pix_fmt yuv420p -movflags +faststart -c:a aac public/input-video.mp4
```

Replace `25` with your composition's fps. See `data-fps` in `public/index.html`.

### 3. Customize the composition

Edit `public/index.html`:

- Card timing: `data-start` and `data-duration` on each `.card-host`
- Text: the `.cap-kicker`, `.cap-title`, `.cap-detail` elements inside each card
- Colors: the `--accent-0` through `--accent-4` custom properties in `:root`
- Motion: the GSAP calls in the trailing `<script>` block (`kineticChars`, `maskReveal`, `growX`, `slideInBottom`, `fadeIn`)

Use `transcript.example.json` as a reference for the word-level transcript shape (`[{ "text", "start", "end" }, ...]`) if you're timing cards against your own audio. Nothing in the composition parses this file automatically. It's there as a timing reference while you hand-author `data-start` and `data-duration`.

### 4. Render

```bash
npx hyperframes check public          # lint the composition first
npx hyperframes render public -o output.mp4 --fps 25 -q high
```

`render` takes the **project directory** (it reads `<dir>/index.html`), not the HTML file itself. Run `npx hyperframes render --help` for the full flag list: quality presets, CRF override, resolution scaling, and more.

## Files

- `generate-hedra-video.sh`: calls the Hedra API to produce the avatar clip
- `public/index.html`: the HyperFrames composition (design system and GSAP timeline)
- `public/vendor/gsap.min.js`: GSAP (MIT)
- `public/fonts/`: Inter (OFL)
- `public/hyperframes.json`: HyperFrames project config
- `transcript.example.json`: example word-level transcript shape
- `demo.mp4`: a real rendered example, for reference

## Hedra API notes

Hedra's public HTTP docs were incomplete and inconsistent when this was built, so the flow in `generate-hedra-video.sh` was confirmed by direct testing rather than taken from a docs page.

- `POST /v3/files` (multipart) uploads a file and returns `{ "url", "content_type", "expires_at" }`. That's a presigned URL, not an id, and it expires in about an hour.
- `POST /v3/models/<model-id>` (e.g. `hedra-character-3`) starts a generation. Body fields match the model's schema, fetchable via Hedra's own tooling: `start_image` and `audio` as `{ "source": "url", "url": ... }`, plus `aspect_ratio`, `resolution`, `prompt` (required), `duration_ms` (optional, defaults to the audio's length).
- `GET /v3/jobs/<job_id>/status` polls the job. Statuses observed: `IN_QUEUE`, `IN_PROGRESS`, `COMPLETED`, `FAILED`. A completed job's response includes an `outputs[]` array with a direct download `url` per output. There's no separate download endpoint.

If Hedra changes this shape, the script's `jq` calls will simply come back empty and it exits with a clear error instead of failing silently.

## Licenses

- GSAP: MIT (see `NOTICE`)
- Inter: OFL (see `NOTICE`)
- This project's code: MIT (see `LICENSE`)

## Bring your own inputs

This repo ships only `demo.mp4` (a finished example). No portrait photo, voice recording, or personal transcript. To use it, supply your own:

- A portrait photo (well-lit, facing the camera)
- A voice recording (MP3/WAV) or a pre-written script if you generate speech elsewhere
- A word-level transcript if you want to time captions precisely (see `transcript.example.json`)

Make sure you have the rights to any voice or likeness you use. Hedra generates a synthetic video of a real person's face and voice.

## Contributing

Issues and PRs welcome, see `CONTRIBUTING.md`.
