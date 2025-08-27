#!/usr/bin/env bash
set -euo pipefail
MODEL="${1:-huihui_ai/qwen3-abliterated:8b}"

log() { printf '[setup] %s\n' "$*" >&2; }

api_ready() {
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1
}

have_model() {
  # NAME column in `ollama list` contains name:tag
  ollama list 2>/dev/null | awk 'NR>1{print $1}' | grep -Fxq "${MODEL}"
}

echo "installing dependeces ...."
# Check ollama
if ! command -v ollama >/dev/null 2>&1; then
  log "Not found. Installing…"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://ollama.com/install.sh | sh
  else
    log "curl not found. Please install curl and rerun."
    exit 1
  fi
else
  log "Already installed."
fi

# Proceed to ensure service and model; continue to show progress logs

# Ensure service is running (do not enable; only start if needed)
if ! pgrep -x ollama >/dev/null 2>&1; then
  log "Starting service…"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user start ollama || true
  fi
  nohup ollama serve >/dev/null 2>&1 &
fi

# Wait until the API is up
for i in {1..50}; do
  if api_ready; then
    break
  fi
  sleep 0.2
  if [[ $i -eq 50 ]]; then
    log "Service did not become ready."
    exit 1
  fi
done

# Pull model if not present
echo "install ai models ...."
if ! have_model; then
  log "Preparing dependencies…"
  ollama pull "${MODEL}"
else
  log "Dependencies already present."
fi

echo "done ....."
echo "thanku"
log "Setup complete."
