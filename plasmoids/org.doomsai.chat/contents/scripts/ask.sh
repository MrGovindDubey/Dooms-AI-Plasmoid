#!/usr/bin/env bash
set -euo pipefail
MODEL="${1:-huihui_ai/qwen3-abliterated:8b}"
PROMPT="${2:-}"

if [[ -z "$PROMPT" ]]; then
  echo "" >&2
  exit 1
fi

api_ready() { curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; }

# Ensure server is up
if ! pgrep -x ollama >/dev/null 2>&1; then
if command -v systemctl >/dev/null 2>&1; then
systemctl --user start ollama || true
fi
nohup ollama serve >/dev/null 2>&1 &
fi

# Wait until the API is up (only if not already ready)
if ! api_ready; then
done
for i in {1..20}; do
  if api_ready; then
    break
  fi
  sleep 0.1
  if [[ $i -eq 20 ]]; then
    echo "Service not ready after quick retry. Please check Ollama service." >&2
    exit 2
  fi
done
fi

# Generate a response using ollama CLI and capture output
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Use generate for single prompt; prints plain text
if ! ollama generate -m "$MODEL" -p "$PROMPT" 2>/dev/null | tee "$TMP" >/dev/null; then
  echo "Failed to generate response" >&2
  exit 3
fi

# Print the captured response
if [[ -s "$TMP" ]]; then
  cat "$TMP"
else
  echo "No response" >&2
  exit 3
fi
