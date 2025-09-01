#!/usr/bin/env bash
set -euo pipefail
MODEL="${1:-huihui_ai/qwen3-abliterated:8b}"

# Progress reporting function
progress() {
  local step="$1"
  local message="$2"
  local percent="${3:-0}"
  local speed="${4:-}"
  if [[ -n "$speed" ]]; then
    echo "PROGRESS:$step:$message:$percent:$speed"
  else
    echo "PROGRESS:$step:$message:$percent"
  fi
}

api_ready() {
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1
}

have_model() {
  ollama list 2>/dev/null | awk 'NR>1{print $1}' | grep -Fxq "${MODEL}"
}

progress "init" "Initializing AI system..." "5"
sleep 1

# Check and install AI engine
if ! command -v ollama >/dev/null 2>&1; then
  progress "engine" "Installing AI engine..." "10"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://ollama.com/install.sh | sh >/dev/null 2>&1
    progress "engine" "AI engine installed successfully" "25"
  else
    progress "error" "Network tools not available" "0"
    exit 1
  fi
else
  progress "engine" "AI engine already available" "25"
fi

sleep 1

# Start AI service
if ! pgrep -x ollama >/dev/null 2>&1; then
  progress "service" "Starting AI service..." "30"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user start ollama >/dev/null 2>&1 || true
  fi
  nohup ollama serve >/dev/null 2>&1 &
  progress "service" "AI service starting..." "35"
else
  progress "service" "AI service already running" "35"
fi

sleep 1

# Wait for service to be ready
progress "service" "Waiting for AI service..." "40"
for i in {1..50}; do
  if api_ready; then
    progress "service" "AI service ready" "45"
    break
  fi
  sleep 0.2
  if [[ $i -eq 50 ]]; then
    progress "error" "AI service failed to start" "0"
    exit 1
  fi
done

sleep 1

# Check and install AI model
if ! have_model; then
  progress "model" "Preparing AI intelligence..." "50"
  
  # Start model download with enhanced progress monitoring
  ollama pull "${MODEL}" 2>&1 | while IFS= read -r line; do
    # Match: pulling 6da140c19a36: 26% ▕█████████████████████ ▏ 1.3 GB/5.0 GB 5.4 MB/s 11m32s
    if [[ "$line" =~ pulling\ ([^:]+):\ *([0-9]+)%.*([0-9.]+\ [KMGT]?B)/([0-9.]+\ [KMGT]?B).*([0-9.]+\ [KMGT]?B/s) ]]; then
      percent="${BASH_REMATCH[2]}"
      downloaded="${BASH_REMATCH[3]}"
      total="${BASH_REMATCH[4]}"
      speed="${BASH_REMATCH[5]}"
      adjusted_percent=$((50 + percent * 45 / 100))
      progress "model" "Downloading AI intelligence... $downloaded/$total" "$adjusted_percent" "$speed"
    # Match: pulling 6da140c19a36: 26% ▕█████████████████████ ▏ 1.3 GB/5.0 GB
    elif [[ "$line" =~ pulling\ ([^:]+):\ *([0-9]+)%.*([0-9.]+\ [KMGT]?B)/([0-9.]+\ [KMGT]?B) ]]; then
      percent="${BASH_REMATCH[2]}"
      downloaded="${BASH_REMATCH[3]}"
      total="${BASH_REMATCH[4]}"
      adjusted_percent=$((50 + percent * 45 / 100))
      progress "model" "Downloading AI intelligence... $downloaded/$total" "$adjusted_percent"
    # Match: pulling 6da140c19a36: 26%
    elif [[ "$line" =~ pulling\ ([^:]+):\ *([0-9]+)% ]]; then
      percent="${BASH_REMATCH[2]}"
      adjusted_percent=$((50 + percent * 45 / 100))
      progress "model" "Downloading AI intelligence... ${percent}%" "$adjusted_percent"
    # Match: pulling manifest
    elif [[ "$line" =~ "pulling manifest" ]]; then
      progress "model" "Connecting to AI repository..." "52"
    # Match: verifying sha256 digest
    elif [[ "$line" =~ "verifying sha256 digest" ]]; then
      progress "model" "Verifying AI intelligence..." "95"
    # Match: success
    elif [[ "$line" =~ "success" ]]; then
      progress "model" "AI intelligence ready" "100"
    fi
  done
else
  progress "model" "AI intelligence already available" "100"
fi

sleep 1
progress "complete" "AI system ready!" "100"