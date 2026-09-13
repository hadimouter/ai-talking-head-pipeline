#!/usr/bin/env bash
# AI Talking Head Pipeline: first-time setup.
# Usage: ./setup.sh

set -euo pipefail

echo "=== AI Talking Head Pipeline Setup ==="
echo ""

# Check for required tools
for tool in curl jq ffmpeg node; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    if [ "$tool" = "node" ]; then
      echo "Error: Node.js is required but not installed."
      echo "       Get it at https://nodejs.org/"
    else
      echo "Error: '$tool' is required but not installed."
      if [ "$tool" = "curl" ]; then
        echo "       macOS: brew install curl"
        echo "       Linux: apt-get install curl"
      elif [ "$tool" = "jq" ]; then
        echo "       macOS: brew install jq"
        echo "       Linux: apt-get install jq"
      elif [ "$tool" = "ffmpeg" ]; then
        echo "       macOS: brew install ffmpeg"
        echo "       Linux: apt-get install ffmpeg"
      fi
    fi
    exit 1
  fi
done

echo "curl, jq, ffmpeg, and Node.js found."
echo ""

# Create .env if it doesn't exist
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example"
  echo "Edit .env and add your HEDRA_API_KEY before running generate-hedra-video.sh"
  echo ""
fi

# Make the generation script executable
chmod +x generate-hedra-video.sh
echo "generate-hedra-video.sh is executable."
echo ""

echo "=== Setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Edit .env with your Hedra API key:"
echo "     https://www.hedra.com/develop/api-keys"
echo "  2. Prepare your inputs (portrait.png, audio.mp3)"
echo "  3. Run: ./generate-hedra-video.sh"
echo "  4. Re-encode with dense keyframes (see README.md step 2)"
echo "  5. Customize public/index.html with your captions"
echo "  6. Render: npx hyperframes render public -o output.mp4"
echo ""
