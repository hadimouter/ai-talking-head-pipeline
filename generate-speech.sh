#!/usr/bin/env bash
# Generates speech audio and a word-level transcript from a text file, using
# HeyGen's text-to-speech API. This is an alternative to recording your own
# voice: give it a script, get back an audio file plus exact word timing,
# ready to feed into generate-hedra-video.sh and into the caption timing in
# public/index.html.
#
# This uses HeyGen's pay-as-you-go API (an API key, not a web-plan login).
# HeyGen removed the free API tier in February 2026, so this costs money:
# a minimum balance purchase, then a per-request rate. Check current pricing
# at https://developers.heygen.com/docs/pricing before running this at any
# real volume. Endpoint: POST https://api.heygen.com/v3/voices/speech
# (documented at https://developers.heygen.com/docs/voices/speech).
#
# The voice must support the "starfish" engine. List compatible voices with:
#   curl -s "https://api.heygen.com/v3/voices?engine=starfish&language=French" \
#        -H "X-Api-Key: $HEYGEN_API_KEY" | jq
set -euo pipefail

API_BASE="https://api.heygen.com/v3"

for bin in curl jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "'$bin' is required but not installed." >&2
    exit 1
  fi
done

if [ -z "${HEYGEN_API_KEY:-}" ]; then
  echo "HEYGEN_API_KEY is not set. Run: export HEYGEN_API_KEY=\"...\"" >&2
  exit 1
fi

if [ -z "${HEYGEN_VOICE_ID:-}" ]; then
  echo "HEYGEN_VOICE_ID is not set. List starfish-compatible voices with:" >&2
  echo "  curl -s \"$API_BASE/voices?engine=starfish\" -H \"X-Api-Key: \$HEYGEN_API_KEY\" | jq" >&2
  exit 1
fi

TEXT_FILE="${1:-}"
AUDIO_OUT="${2:-audio.mp3}"
TRANSCRIPT_OUT="${3:-transcript.json}"

if [ -z "$TEXT_FILE" ] || [ ! -f "$TEXT_FILE" ]; then
  echo "Usage: $0 <script.txt> [audio_out.mp3] [transcript_out.json]" >&2
  exit 1
fi

TEXT="$(cat "$TEXT_FILE")"
BODY=$(jq -n --arg text "$TEXT" --arg voice_id "$HEYGEN_VOICE_ID" \
  --arg speed "${HEYGEN_SPEECH_SPEED:-1}" --arg language "${HEYGEN_LANGUAGE:-}" \
  '{text: $text, voice_id: $voice_id, speed: ($speed | tonumber)} + (if $language == "" then {} else {language: $language} end)')

echo "== Requesting speech ==" >&2
RESPONSE=$(curl -sS --connect-timeout 10 --max-time 60 -X POST "$API_BASE/voices/speech" \
  -H "X-Api-Key: $HEYGEN_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$BODY")

AUDIO_URL=$(echo "$RESPONSE" | jq -r '.data.audio_url // empty')

if [ -z "$AUDIO_URL" ]; then
  echo "$RESPONSE" >&2
  echo "Speech generation failed (no audio_url in the response above)." >&2
  exit 1
fi

echo "== Downloading audio ==" >&2
curl -sS --connect-timeout 10 --max-time 60 "$AUDIO_URL" -o "$AUDIO_OUT"

echo "== Writing transcript ==" >&2
echo "$RESPONSE" | jq '[.data.word_timestamps[]? | select(.word != "<start>" and .word != "<end>") | {text: .word, start: .start, end: .end}]' \
  > "$TRANSCRIPT_OUT"

echo "Saved: $AUDIO_OUT" >&2
echo "Saved: $TRANSCRIPT_OUT" >&2
