#!/usr/bin/env bash
# Uploads a portrait image and an audio file to Hedra, generates a lip-synced
# talking-head video with the Character-3 model, waits for it to finish, and
# downloads the result.
#
# Verified against Hedra's v3 API directly (not from public docs, which are
# sparse/inconsistent at the time of writing): file upload returns a
# presigned `url` (not an id), the generation endpoint is a POST to
# /v3/models/<model>, and job status is polled at /v3/jobs/<job_id>/status.
# If Hedra changes their API shape, `jq` errors here will point at exactly
# which field went missing.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_BASE="https://api.hedra.com/v3"
MODEL="${HEDRA_MODEL:-hedra-character-3}"
ASPECT_RATIO="${HEDRA_ASPECT_RATIO:-3:4}"
RESOLUTION="${HEDRA_RESOLUTION:-720p}"
PROMPT="${HEDRA_PROMPT:-A person speaking naturally and directly to the camera, calm expression, talking-head podcast style, subtle head movement.}"

for bin in curl jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "'$bin' is required but not installed." >&2
    exit 1
  fi
done

if [ -z "${HEDRA_API_KEY:-}" ]; then
  echo "HEDRA_API_KEY is not set. Run: export HEDRA_API_KEY=\"...\"" >&2
  exit 1
fi

IMAGE_FILE="${1:-$DIR/portrait.png}"
AUDIO_FILE="${2:-$DIR/audio.mp3}"
OUT_FILE="${3:-$DIR/hedra-output.mp4}"

for f in "$IMAGE_FILE" "$AUDIO_FILE"; do
  if [ ! -f "$f" ]; then
    echo "Input file not found: $f" >&2
    echo "Usage: $0 [image_file] [audio_file] [output_file]" >&2
    exit 1
  fi
done

echo "== Uploading image ==" >&2
IMAGE_URL=$(curl -sS --connect-timeout 10 --max-time 120 -X POST "$API_BASE/files" \
  -H "Authorization: Bearer $HEDRA_API_KEY" \
  -F "file=@$IMAGE_FILE" | jq -r '.url')

if [ -z "$IMAGE_URL" ] || [ "$IMAGE_URL" = "null" ]; then
  echo "Image upload failed (no url in response)." >&2
  exit 1
fi

echo "== Uploading audio ==" >&2
AUDIO_URL=$(curl -sS --connect-timeout 10 --max-time 120 -X POST "$API_BASE/files" \
  -H "Authorization: Bearer $HEDRA_API_KEY" \
  -F "file=@$AUDIO_FILE" | jq -r '.url')

if [ -z "$AUDIO_URL" ] || [ "$AUDIO_URL" = "null" ]; then
  echo "Audio upload failed (no url in response)." >&2
  exit 1
fi

# Uploaded file URLs are presigned and expire in roughly one hour — the
# generation call below must happen well within that window.

echo "== Requesting generation ($MODEL, $RESOLUTION, $ASPECT_RATIO) ==" >&2
GEN_RESPONSE=$(curl -sS --connect-timeout 10 --max-time 30 -X POST "$API_BASE/models/$MODEL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $HEDRA_API_KEY" \
  -d "{
    \"start_image\": { \"source\": \"url\", \"url\": \"$IMAGE_URL\" },
    \"audio\": { \"source\": \"url\", \"url\": \"$AUDIO_URL\" },
    \"aspect_ratio\": \"$ASPECT_RATIO\",
    \"resolution\": \"$RESOLUTION\",
    \"prompt\": \"$PROMPT\"
  }")
echo "$GEN_RESPONSE" >&2

JOB_ID=$(echo "$GEN_RESPONSE" | jq -r '.job.job_id // .job_id // empty')

if [ -z "$JOB_ID" ]; then
  echo "Could not find a job id in the response above." >&2
  exit 1
fi

echo "== Waiting for job $JOB_ID ==" >&2
while true; do
  STATUS_RESPONSE=$(curl -sS --connect-timeout 10 --max-time 15 "$API_BASE/jobs/$JOB_ID/status" \
    -H "Authorization: Bearer $HEDRA_API_KEY")
  STATE=$(echo "$STATUS_RESPONSE" | jq -r '.job.status // .status // empty')
  echo "status: $STATE" >&2

  if [ "$STATE" = "COMPLETED" ]; then
    VIDEO_URL=$(echo "$STATUS_RESPONSE" | jq -r '(.job.outputs // .outputs // [])[0].url // empty')
    break
  fi
  if [ "$STATE" = "FAILED" ] || [ -z "$STATE" ]; then
    echo "$STATUS_RESPONSE" >&2
    exit 1
  fi
  sleep 10
done

if [ -z "$VIDEO_URL" ]; then
  echo "Job completed but no output url was found in the response above." >&2
  exit 1
fi

echo "== Downloading result ==" >&2
curl -sS --connect-timeout 10 --max-time 300 "$VIDEO_URL" -o "$OUT_FILE"
echo "Saved: $OUT_FILE" >&2
