#!/bin/bash
set -e

INPUT_DIR="input"
OUTPUT_DIR="output"
WHISPER_MODEL="mlx-community/whisper-large-v3-turbo"
WHISPER_BIN="/Users/hau/Library/Python/3.9/bin/mlx_whisper"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load API key from .env
if [ -f "$SCRIPT_DIR/.env" ]; then
  export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
fi

# Find media file in input/
INPUT_FILE=$(find "$INPUT_DIR" -type f \( -name "*.mov" -o -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.webm" -o -name "*.mp3" -o -name "*.wav" -o -name "*.m4a" -o -name "*.flac" -o -name "*.ogg" \) | head -1)

if [ -z "$INPUT_FILE" ]; then
  echo "Error: No media file found in $INPUT_DIR/"
  echo "Drop a video or audio file and re-run."
  exit 1
fi

mkdir -p "$OUTPUT_DIR" tmp

# Step 1: Extract audio (skip for audio files)
EXT="${INPUT_FILE##*.}"
AUDIO_EXTS="mp3 wav m4a flac ogg"

if echo "$AUDIO_EXTS" | grep -qw "$EXT"; then
  echo "==> Audio file detected: $INPUT_FILE"
  WHISPER_INPUT="$INPUT_FILE"
else
  echo "==> Extracting audio from: $INPUT_FILE"
  ffmpeg -i "$INPUT_FILE" -vn -acodec pcm_s16le -ar 16000 -ac 1 tmp/audio.wav -y -loglevel warning
  WHISPER_INPUT="tmp/audio.wav"
fi

# Step 2: Transcribe
echo "==> Transcribing with Whisper (large-v3-turbo)..."
"$WHISPER_BIN" "$WHISPER_INPUT" \
  --language en \
  --model "$WHISPER_MODEL" \
  --output-format txt \
  --output-dir tmp/ \
  2>&1 | grep -E "^\[" || true

BASENAME=$(basename "$WHISPER_INPUT" | sed 's/\.[^.]*$//')
cp "tmp/${BASENAME}.txt" "$OUTPUT_DIR/transcript.txt"
echo "==> Transcript saved: $OUTPUT_DIR/transcript.txt"

# Step 3: Generate summary + mind maps via Claude API
if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "==> Skipping summary & mind maps (no ANTHROPIC_API_KEY in .env)"
  echo ""
  echo "==> Done! Output:"
  echo "  $OUTPUT_DIR/transcript.txt"
  exit 0
fi

echo "==> Generating summary & mind maps with Claude API..."
python3 "$SCRIPT_DIR/mindmap.py" "$OUTPUT_DIR/transcript.txt" "$OUTPUT_DIR"

# Step 4: Render interactive HTML mind maps
echo "==> Rendering interactive mind maps..."
npx markmap-cli "$OUTPUT_DIR/mindmap_en.md" -o "$OUTPUT_DIR/mindmap_en.html" --no-open 2>/dev/null
npx markmap-cli "$OUTPUT_DIR/mindmap_vi.md" -o "$OUTPUT_DIR/mindmap_vi.html" --no-open 2>/dev/null

echo ""
echo "==> Done! Output:"
echo "  $OUTPUT_DIR/transcript.txt     - Raw transcript"
echo "  $OUTPUT_DIR/summary.md         - Summary"
echo "  $OUTPUT_DIR/mindmap_en.html    - Mind map (English)"
echo "  $OUTPUT_DIR/mindmap_vi.html    - Mind map (Vietnamese)"
