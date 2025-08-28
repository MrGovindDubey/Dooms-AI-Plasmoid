load the#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-huihui_ai/qwen3-abliterated:8b}"
PROGRESS_FILE="/tmp/dooms-ai-progress.txt"
SETUP_PID_FILE="/tmp/dooms-ai-setup.pid"

# Progress reporting function
progress() {
  local step="$1"
  local message="$2"
  local percent="${3:-0}"
  local speed="${4:-}"

  # Do not allow percent to go backwards if we have a resume baseline
  if [[ -n "${RESUME_BASELINE:-}" && "${RESUME_BASELINE}" =~ ^[0-9]+$ ]]; then
    if (( percent < RESUME_BASELINE )); then
      percent="$RESUME_BASELINE"
    fi
  fi

  # Always emit 4 fields; include speed inside the message if present
  if [[ -n "$speed" ]]; then
    message="$message [$speed]"
  fi
  local output="PROGRESS:$step:$message:$percent"
  echo "$output"
  echo "$output" > "$PROGRESS_FILE"
}

# Clean up function
cleanup() {
  # Preserve $PROGRESS_FILE to allow resume baseline across runs
  rm -f "$SETUP_PID_FILE"
}
trap cleanup EXIT

# Check if setup is already running
if [[ -f "$SETUP_PID_FILE" ]]; then
  if kill -0 "$(cat "$SETUP_PID_FILE")" 2>/dev/null; then
    echo "Setup already running with PID $(cat "$SETUP_PID_FILE")"
    # Monitor existing setup
    while [[ -f "$SETUP_PID_FILE" ]] && kill -0 "$(cat "$SETUP_PID_FILE")" 2>/dev/null; do
      if [[ -f "$PROGRESS_FILE" ]]; then
        cat "$PROGRESS_FILE"
      fi
      sleep 0.5
    done
    exit 0
  else
    rm -f "$SETUP_PID_FILE"
  fi
fi

# Store our PID
echo $$ > "$SETUP_PID_FILE"

api_ready() {
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1
}

have_model() {
  ollama list 2>/dev/null | awk 'NR>1{print $1}' | grep -Fxq "${MODEL}"
}

# Determine resume baseline from last known progress
RESUME_BASELINE=0
QUIET_BEFORE_MODEL=false
if [[ -f "$PROGRESS_FILE" ]]; then
  last_line=$(tail -n 1 "$PROGRESS_FILE" 2>/dev/null || true)
  last_percent=$(echo "$last_line" | awk -F: '{print $NF}' | sed 's/[^0-9]//g')
  if [[ -n "$last_percent" ]]; then
    RESUME_BASELINE="$last_percent"
  fi
fi
if (( RESUME_BASELINE >= 50 && RESUME_BASELINE < 100 )); then
  QUIET_BEFORE_MODEL=true
fi

if [[ "$QUIET_BEFORE_MODEL" == false ]]; then
  progress "init" "Initializing AI system..." "5"
  sleep 1
fi

# Check and install AI engine
if ! command -v ollama >/dev/null 2>&1; then
  if [[ "$QUIET_BEFORE_MODEL" == false ]]; then
    progress "engine" "Installing AI engine..." "10"
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://ollama.com/install.sh | sh >/dev/null 2>&1
    if [[ "$QUIET_BEFORE_MODEL" == false ]]; then
      progress "engine" "AI engine installed successfully" "25"
    fi
  else
    progress "error" "Network tools not available" "0"
    exit 1
  fi
else
  if [[ "$QUIET_BEFORE_MODEL" == false ]]; then
    progress "engine" "AI engine already available" "25"
  fi
fi

sleep 1

# Start AI service
if ! pgrep -x ollama >/dev/null 2>&1; then
  if [[ "$QUIET_BEFORE_MODEL" == false ]]; then
    progress "service" "Starting AI service..." "30"
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user start ollama >/dev/null 2>&1 || true
  fi
  nohup ollama serve >/dev/null 2>&1 &
  if [[ "$QUIET_BEFORE_MODEL" == false ]]; then
    progress "service" "AI service starting..." "35"
  fi
else
  if [[ "$QUIET_BEFORE_MODEL" == false ]]; then
    progress "service" "AI service already running" "35"
  fi
fi

sleep 1

# Wait for service to be ready
if [[ "$QUIET_BEFORE_MODEL" == false ]]; then
  progress "service" "Waiting for AI service..." "40"
fi
for i in {1..50}; do
  if api_ready; then
    if [[ "$QUIET_BEFORE_MODEL" == false ]]; then
      progress "service" "AI service ready" "45"
    fi
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
  if [[ "$QUIET_BEFORE_MODEL" == false ]]; then
    progress "model" "Preparing AI intelligence..." "50"
  fi

  # Use Ollama HTTP API for accurate, resumable progress (bytes completed/total)
  first_progress_reported=false
  last_completed=0
  last_time=$(date +%s)
  last_speed=""

  curl -sN -X POST -H "Content-Type: application/json" \
    --data "{\"name\":\"${MODEL}\"}" \
    http://127.0.0.1:11434/api/pull | while IFS= read -r line; do
    # Extract fields from JSON line without requiring jq
    status=$(echo "$line" | sed -n 's/.*"status":"\([^"}]*\)".*/\1/p')
    completed=$(echo "$line" | sed -n 's/.*"completed":\([0-9][0-9]*\).*/\1/p')
    total=$(echo "$line" | sed -n 's/.*"total":\([0-9][0-9]*\).*/\1/p')

    # Map statuses to messages
    if [[ -n "$status" ]]; then
      if [[ "$status" == "success" ]]; then
        progress "model" "AI intelligence ready" "100"
        break
      elif [[ "$status" == "pulling manifest" ]]; then
        if (( RESUME_BASELINE < 52 )); then
          progress "model" "Connecting to AI repository..." "52"
        fi
      elif [[ "$status" == "verifying sha256 digest" ]]; then
        progress "model" "Verifying AI intelligence..." "95"
      fi
    fi

    if [[ -n "$completed" && -n "$total" && "$total" -gt 0 ]]; then
      percent=$(( completed * 100 / total ))
      adjusted_percent=$(( 50 + percent * 45 / 100 ))

      # Compute speed from deltas
      now=$(date +%s)
      elapsed=$(( now - last_time ))
      speed=""
      if [[ $elapsed -gt 0 ]]; then
        delta=$(( completed - last_completed ))
        if [[ $delta -gt 0 ]]; then
          speed_bps=$(( delta / elapsed ))
          if command -v awk >/dev/null 2>&1; then
            if [[ $speed_bps -ge 1073741824 ]]; then
              speed=$(awk "BEGIN {printf \"%.1f GB/s\", $speed_bps/1073741824}")
            elif [[ $speed_bps -ge 1048576 ]]; then
              speed=$(awk "BEGIN {printf \"%.1f MB/s\", $speed_bps/1048576}")
            elif [[ $speed_bps -ge 1024 ]]; then
              speed=$(awk "BEGIN {printf \"%.1f KB/s\", $speed_bps/1024}")
            else
              speed="${speed_bps} B/s"
            fi
          else
            speed="${speed_bps} B/s"
          fi
          last_speed="$speed"
        fi
      fi
      last_time=$now
      last_completed=$completed

      # Human readable sizes
      if command -v numfmt >/dev/null 2>&1; then
        hr_completed=$(numfmt --to=iec --suffix=B --format="%.1f" "$completed")
        hr_total=$(numfmt --to=iec --suffix=B --format="%.1f" "$total")
      else
        hr_completed="${completed} B"
        hr_total="${total} B"
      fi

      if [[ "$first_progress_reported" == false && "$percent" -gt 0 ]]; then
        # Use last known speed if current speed is empty
        [[ -z "$speed" && -n "$last_speed" ]] && speed="$last_speed"
        progress "model" "Resuming download from ${percent}% (${hr_completed}/${hr_total})" "$adjusted_percent" "$speed"
        first_progress_reported=true
        sleep 1
      fi

      # Use last known speed if current speed is empty to keep message consistent
      [[ -z "$speed" && -n "$last_speed" ]] && speed="$last_speed"
      progress "model" "Downloading AI intelligence... $hr_completed/$hr_total (${percent}%)" "$adjusted_percent" "$speed"
    fi
  done
else
  progress "model" "AI intelligence already available" "100"
fi

sleep 1
progress "complete" "AI system ready!" "100"

# Clean up
cleanup